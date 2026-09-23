import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { validateContract } from "./validate.ts";

Deno.test("contract validates clean", () => {
  const res = validateContract(new URL(".", import.meta.url).pathname);
  assertEquals(res.errors, []);
  assertEquals(res.ok, true);
});

// A magic row count is a tripwire, not a test — it fails on every legitimate addition and
// says nothing about COVERAGE. What matters is that every SICM verdict the fleet actually
// emits is mapped. These five were sampled from production door telemetry (2026-09); three
// were unmapped at the time, including a GRANT that r13.58.52 makes the normal path for
// every newly-joined member.
Deno.test("every SICM verdict the fleet emits is mapped", async () => {
  const p = new URL("./conformance/denial-mapping.json", import.meta.url);
  const rows: Array<{ sicm: string; friendly: string; result: string }> = JSON.parse(await Deno.readTextFile(p));
  const table = rows.map((r) => [r.sicm.toLowerCase(), r] as const);
  // first substring match wins, exactly as the packages resolve it
  const resolve = (raw: string) => table.find(([k]) => raw.toLowerCase().includes(k))?.[1];

  const observed: Array<[string, string, string]> = [
    ["Granted by provider cache", "Access Granted", "granted"],
    // r13.58.52: an uncached member is adjudicated live, so this is the NEW-MEMBER grant path
    ["Granted by provider source", "Access Granted", "granted"],
    ["Blocked by provider : Client does not have valid membership for that location.",
     "No active membership for this location", "denied"],
    ["Blocked by provider : ClientNotFound : Client with Custom ID 80E004 does not exist.",
     "Member not found", "denied"],
    ["Blocked by provider : 604 : Client not found", "Member not found", "denied"],
  ];
  for (const [raw, friendly, result] of observed) {
    const hit = resolve(raw);
    assertEquals(hit?.friendly, friendly, `unmapped or mis-mapped SICM verdict: ${raw}`);
    assertEquals(hit?.result, result, `wrong result for: ${raw}`);
  }
});

// The "for that location" wording is a CATCH-ALL, not a location verdict: with
// crossregionallookup=false SICM sets it as the DEFAULT before the checks run, so wrong
// location, expired, suspended AND no-membership-at-all all emit it (proven on a bench
// 2026-09-23). The member-facing text must therefore not claim the cause is the location.
Deno.test("the location catch-all does not tell the member it is a location problem", async () => {
  const p = new URL("./conformance/denial-mapping.json", import.meta.url);
  const rows: Array<{ sicm: string; friendly: string }> = JSON.parse(await Deno.readTextFile(p));
  const row = rows.find((r) => r.sicm.includes("valid membership for that location"));
  assertEquals(Boolean(row), true, "the most common real-world denial must be mapped");
  assertEquals(/wrong location|different location|another location/i.test(row!.friendly), false,
    `must not blame the location: ${row!.friendly}`);
});

Deno.test("mock scenarios cover granted + a denial", async () => {
  const p = new URL("./conformance/mock-scenarios.json", import.meta.url);
  const rows = JSON.parse(await Deno.readTextFile(p));
  assertEquals(rows.find((r: { scenario: string }) => r.scenario === "granted")?.result, "granted");
  assertEquals(rows.find((r: { scenario: string }) => r.scenario === "member_not_found")?.result, "denied");
});
