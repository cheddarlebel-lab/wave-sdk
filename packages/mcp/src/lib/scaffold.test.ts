import { describe, it, expect } from "vitest";
import { scaffold } from "./scaffold.js";
import { llmsText } from "./docs.js";

describe("scaffold", () => {
  it("web scaffold is runnable and references the gateway endpoints", () => {
    const r = scaffold("web", "drop-in");
    expect(r.preview).toBe(false);
    expect(r.files.map((f) => f.path).sort()).toEqual(["index.html", "wave-unlock.js"]);
    const js = r.files.find((f) => f.path === "wave-unlock.js")!.contents;
    expect(js).toContain("/partner-auth/token");
    expect(js).toContain("/unlock-stream");
    expect(js).toContain("496b2c43-b05e-4a9a-9592-535173b7ab51"); // service uuid present
    expect(js).toContain("writeValueWithoutResponse");
  });

  it("native platforms return a preview marker, no files", () => {
    for (const p of ["ios", "android", "react-native", "flutter"]) {
      const r = scaffold(p, "headless");
      expect(r.preview).toBe(true);
      expect(r.files.length).toBe(0);
    }
  });

  it("unknown platform is flagged", () => {
    expect(scaffold("commodore64", "x").notes[0]).toMatch(/Unknown platform/);
  });
});

describe("docs", () => {
  it("llmsText documents the gateway + keys", () => {
    const t = llmsText();
    expect(t).toContain("/unlock-stream");
    expect(t).toContain("wave_pub_");
    expect(t).toContain("wave_simulate_unlock");
  });
});
