import { describe, it, expect, vi } from "vitest";
import { registerPartner, getToken, emitMock, readStream, type GatewayConfig } from "./gateway.js";

function stubFetch(status: number, body: unknown) {
  return vi.fn(async () =>
    new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } })
  ) as unknown as typeof fetch;
}

const base: GatewayConfig = { baseUrl: "https://gw.example/api" };

describe("gateway client", () => {
  it("register sends admin header + allowed_sites", async () => {
    const f = stubFetch(200, { partner_id: "p", publishable_key: "wave_pub_x", secret_key: "s", test_key: "t" });
    const cfg = { ...base, adminKey: "admin", fetchImpl: f };
    const r = await registerPartner(cfg, "Co", ["S1"]);
    expect(r.partner_id).toBe("p");
    const [url, init] = (f as unknown as ReturnType<typeof vi.fn>).mock.calls[0];
    expect(url).toBe("https://gw.example/api/partner-auth/register");
    expect((init.headers as Record<string, string>)["x-wave-admin-key"]).toBe("admin");
    // Security: the SDK must never send a Supabase key — the branded gateway injects it.
    expect((init.headers as Record<string, string>)["apikey"]).toBeUndefined();
    expect(JSON.parse(init.body as string)).toEqual({ name: "Co", allowed_sites: ["S1"] });
  });

  it("register without adminKey throws before fetch", async () => {
    await expect(registerPartner(base, "Co", ["S1"])).rejects.toThrow("adminKey required");
  });

  it("getToken posts the key", async () => {
    const f = stubFetch(200, { token: "tok", mode: "test", expires_in: 300 });
    const r = await getToken({ ...base, fetchImpl: f }, "wave_test_x");
    expect(r.mode).toBe("test");
  });

  it("readStream sends Bearer token", async () => {
    const f = stubFetch(200, { status: "granted", reason: "[mock] Access Granted" });
    const cfg = { ...base, fetchImpl: f };
    const r = await readStream(cfg, "tok", "10001");
    expect(r.status).toBe("granted");
    const [, init] = (f as unknown as ReturnType<typeof vi.fn>).mock.calls[0];
    expect((init.headers as Record<string, string>)["Authorization"]).toBe("Bearer tok");
  });

  it("surfaces gateway error bodies", async () => {
    const f = stubFetch(403, { error: "unlock-mock requires a test-mode token" });
    await expect(emitMock({ ...base, fetchImpl: f }, "tok", "10001", "granted")).rejects.toThrow(
      "test-mode token",
    );
  });
});
