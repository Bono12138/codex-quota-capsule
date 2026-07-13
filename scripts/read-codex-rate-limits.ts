import { createSnapshotRecord } from "@quota-capsule/core";
import { readCodexRateLimits } from "@quota-capsule/source-codex";

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
