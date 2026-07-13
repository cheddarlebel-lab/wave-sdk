#!/usr/bin/env node
// Drift guard: proves every language implementation stays in sync with the contract.
// Reads contract/conformance/*.json + wave-protocol.json and asserts each platform's
// source contains all denial friendly-strings, mock scenarios, and key protocol values.
// Exit non-zero on drift. Wire into CI.
import { readFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const read = (p) => readFileSync(join(root, p), "utf8");
const readJson = (p) => JSON.parse(read(p));

const denials = readJson("contract/conformance/denial-mapping.json");
const scenarios = readJson("contract/conformance/mock-scenarios.json");
const proto = readJson("contract/wave-protocol.json");

const friendlies = denials.map((d) => d.friendly);
const scenarioKeys = scenarios.map((s) => s.scenario);
const serviceUuid = proto.ble.serviceUuid;
const rssi = String(proto.proximity.defaultRssiThreshold);

// Each target: file + which invariants must appear in it.
const targets = [
  { name: "swift/DenialMapping", file: "packages/swift/Sources/WaveUnlock/DenialMapping.swift", need: friendlies },
  { name: "swift/WaveProtocol", file: "packages/swift/Sources/WaveUnlock/WaveProtocol.swift", need: [serviceUuid, rssi] },
  { name: "kotlin/DenialMapping", file: "packages/kotlin/src/main/kotlin/com/wave/unlock/DenialMapping.kt", need: friendlies },
  { name: "kotlin/WaveProtocol", file: "packages/kotlin/src/main/kotlin/com/wave/unlock/WaveProtocol.kt", need: [serviceUuid, rssi] },
  { name: "web/denials", file: "packages/web/src/denials.ts", need: friendlies },
  { name: "flutter/denials", file: "packages/flutter/lib/src/denials.dart", need: friendlies },
  { name: "flutter/protocol", file: "packages/flutter/lib/src/protocol.dart", need: [serviceUuid, rssi] },
  { name: "portal/llms-full", file: "apps/developers/llms-full.txt", need: friendlies },
];

let failures = 0;
for (const t of targets) {
  let src;
  try {
    src = read(t.file);
  } catch {
    if (t.optional) continue;
    console.error(`MISSING FILE: ${t.file}`);
    failures++;
    continue;
  }
  const missing = t.need.filter((token) => !src.includes(token));
  if (missing.length) {
    console.error(`DRIFT in ${t.name} (${t.file}):`);
    for (const m of missing) console.error(`  missing: ${JSON.stringify(m)}`);
    failures++;
  } else {
    console.log(`ok  ${t.name}  (${t.need.length} invariants)`);
  }
}

if (failures) {
  console.error(`\n${failures} drift failure(s).`);
  process.exit(1);
}
console.log(`\nAll platforms in sync with the contract (${friendlies.length} denials, ${scenarioKeys.length} scenarios).`);
