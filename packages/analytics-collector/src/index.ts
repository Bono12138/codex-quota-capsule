import { appendFile, mkdir } from "node:fs/promises";
import { dirname } from "node:path";

export const analyticsSchemaVersion = 1;

export const allowedCollectionTiers = [
  "essential_diagnostics",
  "product_improvement",
] as const;

export type CollectionTier = (typeof allowedCollectionTiers)[number];

export type AnalyticsValidationResult =
  | { ok: true; event: Record<string, unknown> }
  | { ok: false; status: number; error: string };

const requiredStringFields = [
  "event_id",
  "event_name",
  "install_id_hash",
  "app_version",
  "locale",
  "arch",
  "analytics_consent_version",
  "language",
] as const;

const forbiddenFieldPatterns = [
  /prompt/i,
  /session/i,
  /token/i,
  /cookie/i,
  /api[_-]?key/i,
  /file[_-]?path/i,
  /project[_-]?name/i,
  /window[_-]?title/i,
  /code/i,
  /command/i,
  /cwd/i,
  /path/i,
];

const allowedEventNames = new Set([
  "app_launched",
  "app_quit",
  "app_heartbeat",
  "quota_refresh_started",
  "quota_refresh_succeeded",
  "quota_refresh_failed",
  "quota_state_sampled",
  "capsule_visible",
  "capsule_hidden",
  "capsule_expanded",
  "capsule_collapsed",
  "capsule_resized",
  "capsule_edge_hidden",
  "capsule_edge_revealed",
  "feedback_window_opened",
  "feedback_clicked",
  "feedback_nudge_shown",
  "feedback_nudge_decision",
  "onboarding_started",
  "onboarding_step_viewed",
  "onboarding_completed",
  "onboarding_skipped",
  "language_selected",
  "menu_opened",
  "settings_opened",
  "analytics_consent_changed",
  "local_history_cleared",
]);

export function validateAnalyticsEvent(input: unknown): AnalyticsValidationResult {
  if (!isRecord(input)) {
    return invalid(400, "payload must be a JSON object");
  }

  for (const field of requiredStringFields) {
    if (typeof input[field] !== "string" || input[field].trim() === "") {
      return invalid(400, `missing required string field: ${field}`);
    }
  }

  const eventName = input.event_name;
  if (typeof eventName !== "string" || !allowedEventNames.has(eventName)) {
    return invalid(400, "event_name is not registered");
  }

  if (typeof input.event_time !== "number" || !Number.isFinite(input.event_time)) {
    return invalid(400, "event_time must be a finite number");
  }

  if (input.schema_version !== analyticsSchemaVersion) {
    return invalid(400, "schema_version is unsupported");
  }

  if (!isRecord(input.properties)) {
    return invalid(400, "properties must be an object");
  }

  const tier = input.properties.collection_tier;
  if (!allowedCollectionTiers.includes(tier as CollectionTier)) {
    return invalid(400, "properties.collection_tier is invalid");
  }

  const forbiddenField = findForbiddenField(input);
  if (forbiddenField) {
    return invalid(400, `forbidden analytics field: ${forbiddenField}`);
  }

  return { ok: true, event: input };
}

export async function appendAnalyticsEvent(filePath: string, event: Record<string, unknown>) {
  await mkdir(dirname(filePath), { recursive: true });
  await appendFile(filePath, `${JSON.stringify(event)}\n`, "utf8");
}

function invalid(status: number, error: string): AnalyticsValidationResult {
  return { ok: false, status, error };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function findForbiddenField(value: unknown, prefix = ""): string | null {
  if (!isRecord(value)) {
    return null;
  }

  for (const [key, nested] of Object.entries(value)) {
    const path = prefix ? `${prefix}.${key}` : key;
    if (forbiddenFieldPatterns.some((pattern) => pattern.test(key))) {
      return path;
    }
    const nestedForbidden = findForbiddenField(nested, path);
    if (nestedForbidden) {
      return nestedForbidden;
    }
  }

  return null;
}
