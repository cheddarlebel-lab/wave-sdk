import { readFileSync, existsSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";

export type Finding = { level: "error" | "warn" | "ok"; message: string };

function findFile(dir: string, name: string, maxDepth = 4): string | null {
  const stack: Array<{ d: string; depth: number }> = [{ d: dir, depth: 0 }];
  while (stack.length) {
    const { d, depth } = stack.pop()!;
    let entries: string[];
    try {
      entries = readdirSync(d);
    } catch {
      continue;
    }
    for (const e of entries) {
      if (e === "node_modules" || e === ".git" || e === "Pods" || e === "build") continue;
      const p = join(d, e);
      let st;
      try {
        st = statSync(p);
      } catch {
        continue;
      }
      if (st.isFile() && e === name) return p;
      if (st.isDirectory() && depth < maxDepth) stack.push({ d: p, depth: depth + 1 });
    }
  }
  return null;
}

// Scans a partner project for the common integration-time BLE mistakes that
// otherwise only surface as a silent runtime failure at the door.
export function doctorProject(dir: string): Finding[] {
  const findings: Finding[] = [];
  if (!existsSync(dir)) return [{ level: "error", message: `path not found: ${dir}` }];

  const infoPlist = findFile(dir, "Info.plist");
  const manifest = findFile(dir, "AndroidManifest.xml");

  if (!infoPlist && !manifest) {
    findings.push({
      level: "warn",
      message: "No Info.plist or AndroidManifest.xml found — is this an iOS/Android app project?",
    });
  }

  if (infoPlist) {
    const t = readFileSync(infoPlist, "utf8");
    if (!t.includes("NSBluetoothAlwaysUsageDescription")) {
      findings.push({
        level: "error",
        message: `iOS: Info.plist is missing NSBluetoothAlwaysUsageDescription — CoreBluetooth scanning will be blocked. (${infoPlist})`,
      });
    } else {
      findings.push({ level: "ok", message: "iOS: NSBluetoothAlwaysUsageDescription present" });
    }
    if (!t.includes("bluetooth-central")) {
      findings.push({
        level: "warn",
        message: "iOS: UIBackgroundModes lacks 'bluetooth-central' — background unlock will not work",
      });
    }
  }

  if (manifest) {
    const t = readFileSync(manifest, "utf8");
    for (const perm of ["BLUETOOTH_SCAN", "BLUETOOTH_CONNECT"]) {
      if (!t.includes(perm)) {
        findings.push({
          level: "error",
          message: `Android: AndroidManifest.xml missing ${perm} permission. (${manifest})`,
        });
      } else {
        findings.push({ level: "ok", message: `Android: ${perm} permission present` });
      }
    }
  }

  if (findings.length === 0) findings.push({ level: "ok", message: "No integration issues detected" });
  return findings;
}
