import { describe, expect, it } from "vitest";
import { codexPathCandidates, extractCommands } from "../src";

describe("extractCommands", () => {
  it("extracts command names from Codex help output", () => {
    const help = `Usage: codex [OPTIONS] <COMMAND>

Commands:
  exec            Run Codex non-interactively
  review          Run a code review
  debug           Debugging tools
  help            Print this message

Options:
  -h, --help
`;

    expect(extractCommands(help)).toEqual(["exec", "review", "debug", "help"]);
  });
});

describe("codexPathCandidates", () => {
  it("checks GUI-friendly paths and deduplicates PATH entries", () => {
    const candidates = codexPathCandidates("/usr/bin:/opt/homebrew/bin", "/Users/example");

    expect(candidates).toContain("/Users/example/.local/bin/codex");
    expect(candidates).toContain("/Users/example/.codex/packages/standalone/current/bin/codex");
    expect(candidates).toContain("/opt/homebrew/bin/codex");
    expect(candidates).toContain("/usr/bin/codex");
    expect(candidates.filter((candidate) => candidate === "/opt/homebrew/bin/codex")).toHaveLength(1);
  });
});
