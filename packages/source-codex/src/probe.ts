import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

export type CodexProbeResult = {
  codexPath: string | null;
  version: string | null;
  topLevelCommands: string[];
  debugCommands: string[];
  likelyUsageCommand: boolean;
  notes: string[];
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

export function extractCommands(helpText: string): string[] {
  const commandsSection = helpText.split(/\nCommands:\n/)[1]?.split(/\n\n/)[0] ?? "";

  return commandsSection
    .split("\n")
    .map((line) => line.match(/^ {2}([a-z][a-z-]*)(?:\s{2,}|\s*$)/)?.[1])
    .filter((command): command is string => Boolean(command));
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
