import { createSnapshotRecord } from "../packages/core/src/index";
import { readCodexRateLimits } from "../packages/source-codex/src/index";

const capturedAt = new Date();
const snapshot = await readCodexRateLimits({ fetchedAt: capturedAt, timeoutMs: 30_000 });
const record = createSnapshotRecord(snapshot, {
  capturedAt,
  appVersion: "0.0.0-local",
  source: "codex-app-server",
});

console.log(
  JSON.stringify(
    {
      snapshot,
      record,
    },
    null,
    2,
  ),
);
