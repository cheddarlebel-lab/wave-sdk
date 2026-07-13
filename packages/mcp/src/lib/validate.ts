export type KeyKind = "pub" | "sk" | "test" | null;

export function keyKind(key: string): KeyKind {
  if (/^wave_pub_[0-9a-f]{32}$/.test(key)) return "pub";
  if (/^wave_sk_[0-9a-f]{48}$/.test(key)) return "sk";
  if (/^wave_test_[0-9a-f]{32}$/.test(key)) return "test";
  return null;
}

export type ConfigInput = { key?: string; sites?: string[] };

export function validateConfig(input: ConfigInput): { ok: boolean; errors: string[] } {
  const errors: string[] = [];
  const kind = input.key ? keyKind(input.key) : null;
  if (!input.key) {
    errors.push("key is required (wave_pub_* for in-app, wave_test_* for testing)");
  } else if (kind === null) {
    errors.push(`key is malformed: expected wave_pub_/wave_test_/wave_sk_ prefix + hex`);
  } else if (kind === "sk") {
    errors.push("do NOT embed a secret key (wave_sk_*) in an app — use the publishable key");
  }
  if (input.sites !== undefined) {
    if (!Array.isArray(input.sites)) errors.push("sites must be an array of strings");
    else if (input.sites.some((s) => typeof s !== "string" || s.length === 0)) {
      errors.push("every site must be a non-empty string");
    }
  }
  return { ok: errors.length === 0, errors };
}
