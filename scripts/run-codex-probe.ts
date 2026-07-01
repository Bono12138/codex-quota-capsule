import { probeCodexCli } from "@quota-capsule/source-codex";

const result = await probeCodexCli();
console.log(JSON.stringify(result, null, 2));

