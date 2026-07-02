import { createServer, type IncomingMessage } from "node:http";
import { env } from "node:process";
import {
  appendAnalyticsEvent,
  validateAnalyticsEvent,
} from "./index.js";

const port = Number(env.PORT ?? 8787);
const outputFile = env.QUOTA_CAPSULE_ANALYTICS_FILE ?? "local-state/analytics/events.ndjson";

export const server = createServer(async (request, response) => {
  if (request.method === "GET" && request.url === "/healthz") {
    response.writeHead(200, { "content-type": "application/json" });
    response.end(JSON.stringify({ ok: true }));
    return;
  }

  if (request.method !== "POST" || request.url !== "/v1/events") {
    response.writeHead(404, { "content-type": "application/json" });
    response.end(JSON.stringify({ error: "not_found" }));
    return;
  }

  try {
    const body = await readBody(request);
    const payload = JSON.parse(body) as unknown;
    const validation = validateAnalyticsEvent(payload);
    if (!validation.ok) {
      response.writeHead(validation.status, { "content-type": "application/json" });
      response.end(JSON.stringify({ error: validation.error }));
      return;
    }

    await appendAnalyticsEvent(outputFile, validation.event);
    response.writeHead(202, { "content-type": "application/json" });
    response.end(JSON.stringify({ ok: true }));
  } catch {
    response.writeHead(400, { "content-type": "application/json" });
    response.end(JSON.stringify({ error: "invalid_json" }));
  }
});

if (import.meta.url === `file://${process.argv[1]}`) {
  server.listen(port, "127.0.0.1", () => {
    console.log(`Quota Capsule analytics collector listening on http://127.0.0.1:${port}`);
    console.log(`Writing events to ${outputFile}`);
  });
}

function readBody(request: IncomingMessage): Promise<string> {
  return new Promise((resolve, reject) => {
    let body = "";
    request.setEncoding("utf8");
    request.on("data", (chunk: string) => {
      body += chunk;
      if (body.length > 64_000) {
        request.destroy();
        reject(new Error("payload_too_large"));
      }
    });
    request.on("end", () => resolve(body));
    request.on("error", reject);
  });
}
