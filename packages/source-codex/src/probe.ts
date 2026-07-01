import { execFile } from "node:child_process";
import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { createInterface, type Interface } from "node:readline";
import { promisify } from "node:util";
import type { AgentQuotaSnapshot, QuotaWindow } from "@quota-capsule/core";

const execFileAsync = promisify(execFile);

export type CodexProbeResult = {
  codexPath: string | null;
  version: string | null;
  topLevelCommands: string[];
  debugCommands: string[];
  likelyUsageCommand: boolean;
  notes: string[];
};

export type CodexRateLimitParseOptions = {
  fetchedAt: Date;
};

export type CodexAppServerTransport = {
  send(payload: unknown): void | Promise<void>;
  read(): Promise<unknown>;
  close?(): void;
};

export type CodexAppServerReadOptions = {
  fetchedAt?: Date;
  codexPath?: string;
  timeoutMs?: number;
};

export async function probeCodexCli(): Promise<CodexProbeResult> {
  const codexPath = await findCodexPath();

  if (!codexPath) {
    return {
      codexPath: null,
      version: null,
      topLevelCommands: [],
      debugCommands: [],
      likelyUsageCommand: false,
      notes: ["codex binary was not found on PATH."],
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
    version: version.stdout.trim() || null,
    topLevelCommands,
    debugCommands,
    likelyUsageCommand,
    notes,
  };
}

export async function readCodexRateLimits(options: CodexAppServerReadOptions = {}): Promise<AgentQuotaSnapshot> {
  const fetchedAt = options.fetchedAt ?? new Date();
  const codexPath = options.codexPath ?? (await findCodexPath());

  if (!codexPath) {
    return errorSnapshot(fetchedAt, "codex binary was not found on PATH.");
  }

  const transport = new ProcessCodexAppServerTransport(codexPath, options.timeoutMs);

  try {
    return await readCodexRateLimitsFromTransport(transport, { fetchedAt });
  } finally {
    transport.close();
  }
}

export async function readCodexRateLimitsFromTransport(
  transport: CodexAppServerTransport,
  options: CodexRateLimitParseOptions,
): Promise<AgentQuotaSnapshot> {
  try {
    await transport.send({
      jsonrpc: "2.0",
      id: 1,
      method: "initialize",
      params: {
        clientInfo: { name: "quota-capsule", title: "Quota Capsule", version: "0.0.0" },
        capabilities: {},
      },
    });

    const initialized = await readUntilId(transport, 1);
    const initError = readRpcError(initialized);
    if (initError) return errorSnapshot(options.fetchedAt, initError);

    await transport.send({ jsonrpc: "2.0", method: "initialized", params: {} });
    await transport.send({ jsonrpc: "2.0", id: 2, method: "account/rateLimits/read", params: {} });

    const rateLimits = await readUntilId(transport, 2);
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
  private readonly reader: Interface;
  private readonly lines: string[] = [];
  private readonly waiters: Array<(line: string) => void> = [];
  private readonly timeoutMs: number;
  private stderr = "";
  private closed = false;

  constructor(codexPath: string, timeoutMs = 30_000) {
    this.timeoutMs = timeoutMs;
    this.child = spawn(codexPath, ["-s", "read-only", "-a", "untrusted", "app-server"], {
      stdio: ["pipe", "pipe", "pipe"],
    });
    this.reader = createInterface({ input: this.child.stdout });

    this.reader.on("line", (line) => {
      const waiter = this.waiters.shift();
      if (waiter) {
        waiter(line);
        return;
      }
      this.lines.push(line);
    });

    this.child.stderr.on("data", (chunk: Buffer) => {
      this.stderr += chunk.toString("utf8");
    });
  }

  send(payload: unknown): void {
    if (this.closed) throw new Error("codex app-server transport is closed.");
    this.child.stdin.write(`${JSON.stringify(payload)}\n`);
  }

  async read(): Promise<unknown> {
    while (true) {
      const line = await this.readLine();
      try {
        return JSON.parse(line);
      } catch {
        continue;
      }
    }
  }

  close(): void {
    this.closed = true;
    this.reader.close();
    this.child.kill();
  }

  private readLine(): Promise<string> {
    const existing = this.lines.shift();
    if (existing !== undefined) return Promise.resolve(existing);

    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        reject(new Error(`codex app-server timed out after ${this.timeoutMs}ms.${this.stderr ? ` stderr: ${this.stderr}` : ""}`));
      }, this.timeoutMs);

      this.waiters.push((line) => {
        clearTimeout(timeout);
        resolve(line);
      });

      this.child.once("exit", (code) => {
        clearTimeout(timeout);
        reject(new Error(`codex app-server exited before response.${code === null ? "" : ` exit code: ${code}`}`));
      });
    });
  }
}

async function readUntilId(transport: CodexAppServerTransport, id: number): Promise<Record<string, unknown>> {
  for (let attempt = 0; attempt < 50; attempt += 1) {
    const message = readObject(await transport.read());
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

async function findCodexPath(): Promise<string | null> {
  try {
    const result = await execFileAsync("which", ["codex"]);
    return result.stdout.trim() || null;
  } catch {
    return null;
  }
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
