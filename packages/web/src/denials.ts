// SICM reason -> member-facing message. Verbatim from contract/conformance/denial-mapping.json.
const TABLE: Array<[string, string]> = [
  ["Granted by provider cache", "Access Granted"],
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

export function friendly(raw: string | null | undefined): string {
  if (!raw) return "Access denied";
  const cleaned = raw.startsWith("[mock] ") ? raw.slice(7) : raw;
  const lc = cleaned.toLowerCase();
  for (const [sicm, msg] of TABLE) if (lc.includes(sicm.toLowerCase())) return msg;
  for (const [, msg] of TABLE) if (lc === msg.toLowerCase()) return msg;
  return cleaned;
}
