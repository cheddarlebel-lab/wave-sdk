import { DEFAULT_GATEWAY_URL, type WaveWebConfig } from "./types.js";

export type Outcome = { status: "granted" | "denied" | "pending"; reason: string | null };

export class Gateway {
  private base: string;
  constructor(
    private cfg: WaveWebConfig,
    private fetchImpl: typeof fetch = fetch,
  ) {
    this.base = cfg.gatewayUrl ?? DEFAULT_GATEWAY_URL;
  }

  private headers(bearer?: string): Record<string, string> {
    const h: Record<string, string> = { "Content-Type": "application/json" };
    if (bearer) h["Authorization"] = `Bearer ${bearer}`;
    return h;
  }

  async fetchToken(): Promise<string> {
    const res = await this.fetchImpl(`${this.base}/partner-auth/token`, {
      method: "POST",
      headers: this.headers(),
      body: JSON.stringify({ key: this.cfg.publishableKey }),
    });
    const data = await res.json();
    if (!res.ok || !data.token) throw new Error(data?.error ?? "token request failed");
    return data.token as string;
  }

  async readOutcome(token: string): Promise<Outcome> {
    const res = await this.fetchImpl(`${this.base}/unlock-stream`, {
      method: "POST",
      headers: this.headers(token),
      body: JSON.stringify({ card_id: this.cfg.userNumber }),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data?.error ?? "unlock-stream failed");
    return { status: data.status, reason: data.reason ?? null };
  }

  async awaitOutcome(token: string, timeoutMs: number, pollMs: number): Promise<Outcome> {
    const deadline = Date.now() + timeoutMs;
    while (Date.now() < deadline) {
      const o = await this.readOutcome(token).catch(() => null);
      if (o && o.status !== "pending") return o;
      await new Promise((r) => setTimeout(r, pollMs));
    }
    return { status: "pending", reason: null };
  }
}
