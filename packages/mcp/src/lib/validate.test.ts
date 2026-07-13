import { describe, it, expect } from "vitest";
import { validateConfig, keyKind } from "./validate.js";

describe("validateConfig", () => {
  it("accepts a publishable key + sites", () => {
    expect(validateConfig({ key: "wave_pub_" + "a".repeat(32), sites: ["S1"] })).toEqual({
      ok: true,
      errors: [],
    });
  });
  it("rejects a missing key", () => {
    expect(validateConfig({}).ok).toBe(false);
  });
  it("rejects an embedded secret key", () => {
    const r = validateConfig({ key: "wave_sk_" + "a".repeat(48) });
    expect(r.ok).toBe(false);
    expect(r.errors[0]).toMatch(/secret key/);
  });
  it("rejects a malformed key", () => {
    expect(validateConfig({ key: "nope" }).ok).toBe(false);
  });
  it("rejects non-string sites", () => {
    const r = validateConfig({ key: "wave_test_" + "a".repeat(32), sites: ["", "ok"] });
    expect(r.ok).toBe(false);
  });
});

describe("keyKind", () => {
  it("classifies", () => {
    expect(keyKind("wave_pub_" + "a".repeat(32))).toBe("pub");
    expect(keyKind("wave_test_" + "a".repeat(32))).toBe("test");
    expect(keyKind("wave_sk_" + "a".repeat(48))).toBe("sk");
    expect(keyKind("x")).toBe(null);
  });
});
