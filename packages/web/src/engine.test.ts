import { describe, it, expect, vi } from "vitest";
import { WaveUnlock } from "./index.js";
import { friendly } from "./denials.js";
import type { UnlockState, WebTransport } from "./types.js";

const config = { gatewayUrl: "https://x/functions/v1", anonKey: "anon", publishableKey: "wave_pub_x", userNumber: "10001" };

function mockTransport(overrides: Partial<WebTransport> = {}): WebTransport & { written?: Uint8Array } {
  const t: WebTransport & { written?: Uint8Array } = {
    connect: vi.fn(async () => {}),
    write: vi.fn(async (p: Uint8Array) => { t.written = p; }),
    disconnect: vi.fn(),
    ...overrides,
  };
  return t;
}

// Sequence of fetch responses: token, then unlock-stream reads.
function mockFetch(streamStatuses: Array<{ status: string; reason?: string }>) {
  let call = 0;
  return vi.fn(async (url: string) => {
    if (url.endsWith("/partner-auth/token")) {
      return new Response(JSON.stringify({ token: "tok", mode: "test" }), { status: 200 });
    }
    const body = streamStatuses[Math.min(call++, streamStatuses.length - 1)];
    return new Response(JSON.stringify(body), { status: 200 });
  }) as unknown as typeof fetch;
}

async function labels(gen: AsyncGenerator<UnlockState>): Promise<string[]> {
  const out: string[] = [];
  for await (const s of gen) out.push(s.kind);
  return out;
}

describe("WaveUnlock engine", () => {
  it("granted sequence", async () => {
    const transport = mockTransport();
    const wave = new WaveUnlock(config, { transport, fetchImpl: mockFetch([{ status: "granted", reason: "[mock] Access Granted" }]) });
    const seq = await labels(wave.unlock({ cloudTimeoutMs: 500, pollIntervalMs: 10 }));
    expect(seq).toEqual(["scanning", "readerFound", "writing", "awaitingConfirmation", "granted"]);
    expect(Array.from(transport.written!)).toEqual([0x01, ...new TextEncoder().encode("10001")]);
  });

  it("denied sequence maps a friendly reason", async () => {
    const wave = new WaveUnlock(config, { transport: mockTransport(), fetchImpl: mockFetch([{ status: "denied", reason: "Client not found" }]) });
    let reason = "";
    const seq: string[] = [];
    for await (const s of wave.unlock({ cloudTimeoutMs: 500, pollIntervalMs: 10 })) {
      seq.push(s.kind);
      if (s.kind === "denied") reason = s.reason;
    }
    expect(seq).toEqual(["scanning", "readerFound", "writing", "awaitingConfirmation", "denied"]);
    expect(reason).toBe("Member not found");
  });

  it("times out when the cloud stays pending", async () => {
    const wave = new WaveUnlock(config, { transport: mockTransport(), fetchImpl: mockFetch([{ status: "pending" }]) });
    const seq = await labels(wave.unlock({ cloudTimeoutMs: 60, pollIntervalMs: 20 }));
    expect(seq[seq.length - 1]).toBe("timedOut");
  });

  it("fails when the reader won't connect", async () => {
    const transport = mockTransport({ connect: vi.fn(async () => { throw new Error("no device"); }) });
    const wave = new WaveUnlock(config, { transport, fetchImpl: mockFetch([{ status: "granted" }]) });
    const seq = await labels(wave.unlock());
    expect(seq).toEqual(["scanning", "failed"]);
  });
});

describe("friendly", () => {
  it("strips mock tag + matches substrings", () => {
    expect(friendly("[mock] Membership expired")).toBe("Membership expired");
    expect(friendly("Blocked by provider : 604 : Client not found")).toBe("Member not found");
    expect(friendly(null)).toBe("Access denied");
  });
});
