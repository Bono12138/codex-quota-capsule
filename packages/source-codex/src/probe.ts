import { execFile } from "node:child_process";
import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { constants } from "node:fs";
import { access } from "node:fs/promises";
import { homedir } from "node:os";
import { StringDecoder } from "node:string_decoder";
import { promisify } from "node:util";
import type { AgentQuotaSnapshot, QuotaWindow } from "@quota-capsule/core";

const execFileAsync = promisify(execFile);

export type CodexProbeResult = {
  codexPath: string | null;
  checkedPaths: string[];
  version: string | null;
  topLevelCommands: string[];
  debugCommands: string[];
  likelyUsageCommand: boolean;
  notes: string[];
};

export type CodexRateLimitParseOptions = {
  fetchedAt: Date;
  timeoutMs?: number;
};

export type CodexAppServerTransport = {
  send(payload: unknown): void | Promise<void>;
  read(timeoutMs?: number): Promise<unknown>;
  close?(): void;
};

export type CodexAppServerReadOptions = {
  fetchedAt?: Date;
  codexPath?: string;
  timeoutMs?: number;
};

export async function probeCodexCli(): Promise<CodexProbeResult> {
  const resolution = await findCodexPath();
  const codexPath = resolution.codexPath;

  if (!codexPath) {
    return {
      codexPath: null,
      checkedPaths: resolution.checkedPaths,
      version: null,
      topLevelCommands: [],
      debugCommands: [],
      likelyUsageCommand: false,
      notes: [`codex binary was not found. Checked paths: ${resolution.checkedPaths.join(", ")}`],
    };
  }

  const [version, topHelp, debugHelp] = await Promise.all([
    runCodex(codexPath, ["--version"]),
    runCodex(codexPath, ["--help"]),
    runCodex(codexPath, ["debug", "--help"]),
  ]);

  const topLevelCommands = extractCommands(topHelp.stdout);
  const debugCommands = extractCommands(debugHelp.stdout);
  const likelyUsageCommand = [...topLevelCommands, ...debugCommands].some((command) =>
    /usage|quota|limit|billing/i.test(command),
  );

  const notes = [
    likelyUsageCommand
      ? "A possible usage/quota command was found. Inspect it before implementing an adapter."
      : "No obvious usage/quota command was found in the public CLI help surface.",
  ];

  return {
    codexPath,
    checkedPaths: resolution.checkedPaths,
    version: version.stdout.trim() || null,
    topLevelCommands,
    debugCommands,
    likelyUsageCommand,
    notes,
  };
}

export async function readCodexRateLimits(options: CodexAppServerReadOptions = {}): Promise<AgentQuotaSnapshot> {
  const fetchedAt = options.fetchedAt ?? new Date();
  const resolution = options.codexPath
    ? { codexPath: options.codexPath, checkedPaths: [options.codexPath] }
    : await findCodexPath();
  const codexPath = resolution.codexPath;

  if (!codexPath) {
    return errorSnapshot(fetchedAt, `codex binary was not found. Checked paths: ${resolution.checkedPaths.join(", ")}`);
  }

  const transport = new ProcessCodexAppServerTransport(codexPath, options.timeoutMs);

  try {
    return await readCodexRateLimitsFromTransport(transport, { fetchedAt, timeoutMs: options.timeoutMs });
  } finally {
    transport.close();
  }
}

export async function readCodexRateLimitsFromTransport(
  transport: CodexAppServerTransport,
  options: CodexRateLimitParseOptions,
): Promise<AgentQuotaSnapshot> {
  try {
    const requestedTimeout = options.timeoutMs ?? 30_000;
    const timeoutMs = Number.isFinite(requestedTimeout) && requestedTimeout > 0
      ? Math.min(requestedTimeout, 300_000)
      : 30_000;
    const deadline = Date.now() + timeoutMs;
    await transport.send({
      jsonrpc: "2.0",
      id: 1,
      method: "initialize",
      params: {
        clientInfo: { name: "quota-capsule", title: "Quota Capsule", version: "0.0.0" },
        capabilities: {},
      },
    });

    const initialized = await readUntilId(transport, 1, deadline);
    const initError = readRpcError(initialized);
    if (initError) return errorSnapshot(options.fetchedAt, initError);

    await transport.send({ jsonrpc: "2.0", method: "initialized", params: {} });
    await transport.send({ jsonrpc: "2.0", id: 2, method: "account/rateLimits/read", params: {} });

    const rateLimits = await readUntilId(transport, 2, deadline);
    const rateLimitError = readRpcError(rateLimits);
    if (rateLimitError) return errorSnapshot(options.fetchedAt, rateLimitError);

    return parseCodexRateLimits(readObject(rateLimits).result, options);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return errorSnapshot(options.fetchedAt, message);
  }
}

export function extractCommands(helpText: string): string[] {
  const commandsSection = helpText.split(/\nCommands:\n/)[1]?.split(/\n\n/)[0] ?? "";

  return commandsSection
    .split("\n")
    .map((line) => line.match(/^ {2}([a-z][a-z-]*)(?:\s{2,}|\s*$)/)?.[1])
    .filter((command): command is string => Boolean(command));
}

export function parseCodexRateLimits(
  result: unknown,
  options: CodexRateLimitParseOptions,
): AgentQuotaSnapshot {
  const rateLimits = readObject(readObject(result).rateLimits);
  const windows = ["primary", "secondary"]
    .map((key) => parseRateLimitWindow(rateLimits[key]))
    .filter((window): window is QuotaWindow => Boolean(window));

  const shortWindow = windows.find((window) => window.windowMinutes <= 360);
  const weeklyWindow = windows.find((window) => window.windowMinutes > 360);

  if (!shortWindow && !weeklyWindow) {
    return {
      provider: "codex",
      sourceStatus: "error",
      fetchedAt: options.fetchedAt,
      errorMessage: "codex app-server rateLimits did not include any usable windows.",
    };
  }

  if (!shortWindow) {
    return {
      provider: "codex",
      sourceStatus: "error",
      fetchedAt: options.fetchedAt,
      weeklyWindow,
      errorMessage: "codex app-server rateLimits is temporarily missing the required 5-hour quota window.",
    };
  }

  return {
    provider: "codex",
    sourceStatus: "ok",
    fetchedAt: options.fetchedAt,
    shortWindow,
    weeklyWindow,
  };
}

class ProcessCodexAppServerTransport implements CodexAppServerTransport {
  private readonly child: ChildProcessWithoutNullStreams;
  private readonly lines: string[] = [];
  private readonly waiters: Array<{
    resolve: (line: string) => void;
    reject: (error: Error) => void;
    timer: ReturnType<typeof setTimeout>;
  }> = [];
  private readonly timeoutMs: number;
  private stderr = "";
  private closed = false;
  private terminalError: Error | null = null;
  private stdoutBuffer = "";
  private readonly stdoutDecoder = new StringDecoder("utf8");

  constructor(codexPath: string, timeoutMs = 30_000) {
    this.timeoutMs = timeoutMs;
    this.child = spawn(codexPath, ["-s", "read-only", "-a", "untrusted", "app-server"], {
      stdio: ["pipe", "pipe", "pipe"],
    });
    this.child.stdout.on("data", (chunk: Buffer) => this.appendStdout(chunk));

    this.child.stderr.on("data", (chunk: Buffer) => {
      this.stderr += chunk.toString("utf8");
      if (this.stderr.length > 8_192) this.stderr = this.stderr.slice(-8_192);
    });
    this.child.once("error", (error) => this.fail(new Error(`codex app-server failed to start: ${error.message}`)));
    this.child.once("exit", (code) => {
      this.fail(new Error(`codex app-server exited before response.${code === null ? "" : ` exit code: ${code}`}`));
    });
  }

  private acceptLine(line: string): void {
    if (this.terminalError) return;
    if (Buffer.byteLength(line, "utf8") > 1_048_576) {
      this.fail(new Error("codex app-server output exceeded the safety limit."));
      this.child.kill();
      return;
    }
      const waiter = this.waiters.shift();
      if (waiter) {
        clearTimeout(waiter.timer);
        waiter.resolve(line);
        return;
      }
      if (this.lines.length >= 1_000) {
        this.fail(new Error("codex app-server queued too many messages."));
        return;
      }
      this.lines.push(line);
  }

  send(payload: unknown): void {
    if (this.closed) throw new Error("codex app-server transport is closed.");
    this.child.stdin.write(`${JSON.stringify(payload)}\n`);
  }

  async read(timeoutMs = this.timeoutMs): Promise<unknown> {
    const line = await this.readLine(timeoutMs);
    try {
      return JSON.parse(line);
    } catch {
      throw new Error("codex app-server returned an unparseable JSON-RPC message.");
    }
  }

  close(): void {
    this.closed = true;
    this.fail(new Error("codex app-server transport is closed."));
    this.child.kill();
  }

  private appendStdout(chunk: Buffer): void {
    if (this.terminalError) return;
    this.stdoutBuffer += this.stdoutDecoder.write(chunk);
    if (Buffer.byteLength(this.stdoutBuffer, "utf8") > 1_048_576) {
      this.fail(new Error("codex app-server output exceeded the safety limit."));
      this.child.kill();
      return;
    }

    let newline = this.stdoutBuffer.indexOf("\n");
    while (newline >= 0) {
      const line = this.stdoutBuffer.slice(0, newline).replace(/\r$/, "");
      this.stdoutBuffer = this.stdoutBuffer.slice(newline + 1);
      this.acceptLine(line);
      if (this.terminalError) return;
      newline = this.stdoutBuffer.indexOf("\n");
    }
  }

  private readLine(timeoutMs: number): Promise<string> {
    const existing = this.lines.shift();
    if (existing !== undefined) return Promise.resolve(existing);
    if (this.terminalError) return Promise.reject(this.terminalError);

    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        const index = this.waiters.findIndex((waiter) => waiter.resolve === resolve);
        if (index >= 0) this.waiters.splice(index, 1);
        reject(new Error(`codex app-server timed out after ${timeoutMs}ms.${safeStderrSuffix(this.stderr)}`));
      }, Math.max(0, timeoutMs));

      this.waiters.push({ resolve, reject, timer: timeout });
    });
  }

  private fail(error: Error): void {
    if (!this.terminalError) this.terminalError = error;
    for (const waiter of this.waiters.splice(0)) {
      clearTimeout(waiter.timer);
      waiter.reject(this.terminalError);
    }
  }
}

function safeStderrSuffix(stderr: string): string {
  if (!stderr) return "";
  const sanitized = stderr
    .replace(/Bearer\s+\S+/gi, "Bearer [redacted]")
    .replace(/https?:\/\/\S+/g, "[remote service]")
    .replace(/\/Users\/[^/\s]+/g, "/Users/[redacted]")
    .replace(/\s+/g, " ")
    .slice(0, 512);
  return ` stderr: ${sanitized}`;
}

async function readUntilId(
  transport: CodexAppServerTransport,
  id: number,
  deadline: number,
): Promise<Record<string, unknown>> {
  for (let attempt = 0; attempt < 1_000; attempt += 1) {
    const remaining = deadline - Date.now();
    if (remaining <= 0) throw new Error("codex app-server request exceeded its overall deadline.");
    const message = readObject(await transport.read(remaining));
    if (message.id !== id) continue;
    return message;
  }

  throw new Error(`codex app-server did not return response id ${id}.`);
}

function readRpcError(message: Record<string, unknown>): string | null {
  const error = readObject(message.error);
  const messageText = error.message;
  return typeof messageText === "string" ? messageText : null;
}

function errorSnapshot(fetchedAt: Date, errorMessage: string): AgentQuotaSnapshot {
  return {
    provider: "codex",
    sourceStatus: "error",
    fetchedAt,
    errorMessage,
  };
}

export function codexPathCandidates(environmentPath = process.env.PATH ?? "", homeDirectory = homedir()): string[] {
  const explicitCandidates = [
    `${homeDirectory}/.local/bin/codex`,
    `${homeDirectory}/.codex/packages/standalone/current/bin/codex`,
    "/opt/homebrew/bin/codex",
    "/usr/local/bin/codex",
    "/usr/bin/codex",
  ];
  const pathCandidates = environmentPath
    .split(":")
    .filter(Boolean)
    .map((entry) => `${entry}/codex`);

  return [...new Set([...explicitCandidates, ...pathCandidates])];
}

async function findCodexPath(): Promise<{ codexPath: string | null; checkedPaths: string[] }> {
  const checkedPaths = codexPathCandidates();

  for (const candidate of checkedPaths) {
    try {
      await access(candidate, constants.X_OK);
      return { codexPath: candidate, checkedPaths };
    } catch {
      // Keep checking the remaining candidates.
    }
  }

  return { codexPath: null, checkedPaths };
}

async function runCodex(codexPath: string, args: string[]): Promise<{ stdout: string; stderr: string }> {
  try {
    const result = await execFileAsync(codexPath, args, {
      timeout: 10_000,
      maxBuffer: 1024 * 1024,
    });
    return { stdout: result.stdout, stderr: result.stderr };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return { stdout: "", stderr: message };
  }
}

function parseRateLimitWindow(value: unknown): QuotaWindow | null {
  const window = readObject(value);
  const usedPercent = readNumber(window.usedPercent);
  const windowMinutes = readNumber(window.windowDurationMins);
  const resetsAtSeconds = readNumber(window.resetsAt);

  if (usedPercent === null || windowMinutes === null || resetsAtSeconds === null) {
    return null;
  }

  if (
    !Number.isFinite(usedPercent) ||
    usedPercent < 0 ||
    usedPercent > 100 ||
    !Number.isFinite(windowMinutes) ||
    !Number.isInteger(windowMinutes) ||
    windowMinutes < 1 ||
    windowMinutes > 525_600 ||
    !Number.isFinite(resetsAtSeconds) ||
    resetsAtSeconds < 946_684_800 ||
    resetsAtSeconds > 4_102_444_800
  ) {
    return null;
  }

  return {
    label: windowMinutes <= 360 ? "5h" : "weekly",
    windowMinutes,
    usedPercent: clampPercent(usedPercent),
    remainingPercent: clampPercent(100 - usedPercent),
    resetsAt: new Date(resetsAtSeconds * 1000),
  };
}

function readObject(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value) ? (value as Record<string, unknown>) : {};
}

function readNumber(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function clampPercent(value: number): number {
  return Math.min(100, Math.max(0, value));
}
