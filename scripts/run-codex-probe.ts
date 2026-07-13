import { probeCodexCli } from "../packages/source-codex/src/index";

const result = await probeCodexCli();
console.log(JSON.stringify(result, null, 2));
