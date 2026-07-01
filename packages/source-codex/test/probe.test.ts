import { describe, expect, it } from "vitest";
import { extractCommands } from "../src";

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

