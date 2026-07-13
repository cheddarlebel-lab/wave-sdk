import { describe, it, expect, beforeAll, afterAll } from "vitest";
import { mkdtempSync, writeFileSync, mkdirSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { doctorProject } from "./doctor.js";

let dir: string;

beforeAll(() => {
  dir = mkdtempSync(join(tmpdir(), "wave-doctor-"));
});
afterAll(() => rmSync(dir, { recursive: true, force: true }));

describe("doctorProject", () => {
  it("flags missing iOS bluetooth usage string", () => {
    const ios = join(dir, "ios-bad");
    mkdirSync(ios, { recursive: true });
    writeFileSync(join(ios, "Info.plist"), "<plist><dict></dict></plist>");
    const f = doctorProject(ios);
    expect(f.some((x) => x.level === "error" && /NSBluetoothAlwaysUsageDescription/.test(x.message))).toBe(true);
  });

  it("passes a complete iOS plist", () => {
    const ios = join(dir, "ios-ok");
    mkdirSync(ios, { recursive: true });
    writeFileSync(
      join(ios, "Info.plist"),
      "<plist><dict><key>NSBluetoothAlwaysUsageDescription</key><string>Unlock</string><key>UIBackgroundModes</key><array><string>bluetooth-central</string></array></dict></plist>",
    );
    const f = doctorProject(ios);
    expect(f.some((x) => x.level === "error")).toBe(false);
  });

  it("flags missing Android BLE permissions", () => {
    const a = join(dir, "android-bad");
    mkdirSync(a, { recursive: true });
    writeFileSync(join(a, "AndroidManifest.xml"), "<manifest></manifest>");
    const f = doctorProject(a);
    expect(f.filter((x) => x.level === "error").length).toBe(2);
  });

  it("errors on a missing path", () => {
    expect(doctorProject(join(dir, "nope")).length).toBe(1);
  });
});
