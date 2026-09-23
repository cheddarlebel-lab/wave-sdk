// SICM reason -> member-facing message. Verbatim from contract/conformance/denial-mapping.json.
//
// React Native ships to BOTH Apple and Android from one codebase, and this package used to
// forward the raw SICM `reason` straight to the consumer — so every RN partner had to
// hand-roll this table, on both platforms, and would most likely have got the same two
// things wrong the first-party table did: treating "Granted by provider source" as an
// unknown verdict (it is a GRANT, and r13.58.52 makes it the normal path for a newly-joined
// member), and reading "...for that location" as a location problem when it is a catch-all
// that also covers expired, suspended and no-membership.
//
// Order is semantic: resolution is first-substring-match-wins, so a generic key placed above
// a specific one silently changes what a member is told. contract/packages_in_sync_test.ts
// enforces both the contents and the order against the contract.
const TABLE: Array<[string, string]> = [
  ["Granted by provider cache", "Access Granted"],
  ["Granted by provider source", "Access Granted"],
  ["ClientNotFound", "Member not found"],
  ["does not have valid membership for that location", "No active membership for this location"],
  ["No valid contract found", "No active membership"],
  ["Client not found", "Member not found"],
  ["Blocked by schedule", "Outside access hours"],
  ["Maximum active signins", "Maximum active sign-ins reached"],
  ["Checkins limitation", "Daily check-in limit reached"],
  ["Blocked by restriction", "Membership restriction"],
  ["Blocked by client alert", "Account alert"],
  ["Over account balance", "Outstanding balance"],
  ["Liability release", "Liability release required"],
  ["Scheduled visit", "No booking found"],
  ["No member picture", "Photo required"],
  ["Provider not found", "System error - provider unavailable"],
  ["Inactive", "Membership inactive"],
  ["Expired", "Membership expired"],
];

/// Map a raw SICM reason to the member-facing message. Unknown verdicts fall through to the
/// raw string rather than a generic "denied", so a new verdict is visible instead of hidden.
export function friendly(raw: string | null | undefined): string {
  if (!raw) return "Access denied";
  const cleaned = raw.startsWith("[mock] ") ? raw.slice(7) : raw;
  const lc = cleaned.toLowerCase();
  for (const [sicm, msg] of TABLE) if (lc.includes(sicm.toLowerCase())) return msg;
  for (const [, msg] of TABLE) if (lc === msg.toLowerCase()) return msg;
  return cleaned;
}
