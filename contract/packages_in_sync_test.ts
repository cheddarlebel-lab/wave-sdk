// ⛔ The per-language denial tables are HAND-COPIED from
// contract/conformance/denial-mapping.json — each file says "verbatim" and nothing enforced
// it. Only the Swift package had a conformance test; web, kotlin and flutter could drift
// silently, and on 2026-09-23 all four were missing the same four rows, including
// "Granted by provider source" — a GRANT that r13.58.52 makes the normal path for every
// newly-joined member, so partners were shown a raw SICM sentence instead of "Access Granted".
//
// This asserts every package carries every contract key, IN THE SAME ORDER. Order is part of
// the contract: resolution is first-substring-match-wins, so moving a generic key above a
// specific one silently changes what a member is told.
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

const PKGS: Record<string, string> = {
  web: "../packages/web/src/denials.ts",
  kotlin: "../packages/kotlin/src/main/kotlin/com/wave/unlock/DenialMapping.kt",
  flutter: "../packages/flutter/lib/src/denials.dart",
  swift: "../packages/swift/Sources/WaveUnlock/DenialMapping.swift",
  "react-native": "../packages/react-native/src/denials.ts",
};

Deno.test("every package carries the contract denial table, in order", async () => {
  const rows: Array<{ sicm: string; friendly: string }> = JSON.parse(
    await Deno.readTextFile(new URL("./conformance/denial-mapping.json", import.meta.url)),
  );
  for (const [name, rel] of Object.entries(PKGS)) {
    const raw = await Deno.readTextFile(new URL(rel, import.meta.url));
    // Strip comments before matching. Every one of these files explains the table ABOVE it,
    // and that prose quotes contract keys — so a naive indexOf finds the comment, not the
    // row, and the order check then fails on a perfectly correct table. (It did.)
    const src = raw
      .replace(/\/\*[\s\S]*?\*\//g, "")
      .split("\n").filter((l) => !l.trim().startsWith("//")).join("\n");
    const positions: number[] = [];
    for (const r of rows) {
      const at = src.indexOf(r.sicm);
      assertEquals(at >= 0, true, `${name} is missing contract key: ${r.sicm}`);
      // the member-facing text must match too, not just the SICM key
      assertEquals(src.includes(r.friendly), true,
        `${name} has key "${r.sicm}" but not its friendly text "${r.friendly}"`);
      positions.push(at);
    }
    const sorted = [...positions].sort((a, b) => a - b);
    assertEquals(positions, sorted,
      `${name} lists the contract keys out of order — first-substring-match-wins makes order semantic`);
  }
});
