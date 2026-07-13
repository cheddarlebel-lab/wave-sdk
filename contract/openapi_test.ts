import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { parse } from "https://deno.land/std@0.224.0/yaml/mod.ts";

Deno.test("openapi documents all four gateway endpoints", async () => {
  const text = await Deno.readTextFile(new URL("./openapi.yaml", import.meta.url));
  const doc = parse(text) as { paths: Record<string, unknown> };
  for (const p of ["/partner-auth/register", "/partner-auth/token", "/unlock-stream", "/unlock-mock"]) {
    assert(doc.paths[p], `missing path ${p}`);
  }
  assertEquals(Object.keys(doc.paths).length, 4);
});
