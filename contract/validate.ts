export function validateContract(dir: string): { ok: boolean; errors: string[] } {
  const errors: string[] = [];
  const read = (rel: string) => JSON.parse(Deno.readTextFileSync(`${dir}/${rel}`));

  let proto;
  try {
    proto = read("wave-protocol.json");
  } catch (e) {
    return { ok: false, errors: [`wave-protocol.json unreadable: ${(e as Error).message}`] };
  }
  const uuidRe = /^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$/;
  if (!uuidRe.test(proto?.ble?.serviceUuid ?? "")) errors.push("ble.serviceUuid malformed");
  if (!uuidRe.test(proto?.ble?.writeCharacteristicUuid ?? "")) errors.push("ble.writeCharacteristicUuid malformed");
  if (proto?.ble?.payloadPrefix !== 1) errors.push("ble.payloadPrefix must be 1");

  let denials: Array<{ sicm: string; friendly: string; result: string }>;
  try {
    denials = read("conformance/denial-mapping.json");
  } catch (e) {
    return { ok: false, errors: [...errors, `denial-mapping.json unreadable: ${(e as Error).message}`] };
  }
  const seen = new Set<string>();
  for (const d of denials) {
    if (!d.sicm || !d.friendly) errors.push(`denial row missing fields: ${JSON.stringify(d)}`);
    if (d.result !== "granted" && d.result !== "denied") errors.push(`denial row bad result: ${d.sicm}`);
    if (seen.has(d.sicm)) errors.push(`duplicate sicm key: ${d.sicm}`);
    seen.add(d.sicm);
  }

  let scenarios: Array<{ scenario: string; result: string; reason: string }>;
  try {
    scenarios = read("conformance/mock-scenarios.json");
  } catch (e) {
    return { ok: false, errors: [...errors, `mock-scenarios.json unreadable: ${(e as Error).message}`] };
  }
  const friendlySet = new Set(denials.map((d) => d.friendly));
  for (const s of scenarios) {
    if (!friendlySet.has(s.reason)) errors.push(`mock scenario reason not in denial table: ${s.reason}`);
  }

  return { ok: errors.length === 0, errors };
}
