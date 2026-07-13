import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { validateContract } from "./validate.ts";

Deno.test("contract validates clean", () => {
  const res = validateContract(new URL(".", import.meta.url).pathname);
  assertEquals(res.errors, []);
  assertEquals(res.ok, true);
});

Deno.test("denial table has all 14 SICM mappings", async () => {
  const p = new URL("./conformance/denial-mapping.json", import.meta.url);
  const rows = JSON.parse(await Deno.readTextFile(p));
  assertEquals(rows.length, 14);
  assertEquals(
    rows.find((r: { sicm: string }) => r.sicm === "Client not found")?.friendly,
    "Member not found",
  );
});

Deno.test("mock scenarios cover granted + a denial", async () => {
  const p = new URL("./conformance/mock-scenarios.json", import.meta.url);
  const rows = JSON.parse(await Deno.readTextFile(p));
  assertEquals(rows.find((r: { scenario: string }) => r.scenario === "granted")?.result, "granted");
  assertEquals(rows.find((r: { scenario: string }) => r.scenario === "member_not_found")?.result, "denied");
});
