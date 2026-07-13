export type GatewayConfig = {
  baseUrl: string; // https://app.wavepassport.com/api (branded gateway; injects its own key)
  adminKey?: string; // WAVE_ADMIN_KEY, only needed for register
  fetchImpl?: typeof fetch; // injectable for tests
};

export type RegisterResult = {
  partner_id: string;
  publishable_key: string;
  secret_key: string;
  test_key: string;
};

export type TokenResult = { token: string; mode: "live" | "test"; expires_in: number };

export type UnlockStatus = { status: "granted" | "denied" | "pending"; reason: string | null };

function baseHeaders(_cfg: GatewayConfig): Record<string, string> {
  return { "Content-Type": "application/json" };
}

async function post<T>(
  cfg: GatewayConfig,
  path: string,
  body: unknown,
  extraHeaders: Record<string, string> = {},
): Promise<T> {
  const f = cfg.fetchImpl ?? fetch;
  const res = await f(`${cfg.baseUrl}${path}`, {
    method: "POST",
    headers: { ...baseHeaders(cfg), ...extraHeaders },
    body: JSON.stringify(body),
  });
  const text = await res.text();
  let data: unknown;
  try {
    data = text ? JSON.parse(text) : {};
  } catch {
    throw new Error(`Gateway ${path} returned non-JSON (${res.status}): ${text.slice(0, 200)}`);
  }
  if (!res.ok) {
    const msg = (data as { error?: string })?.error ?? `HTTP ${res.status}`;
    throw new Error(`Gateway ${path} failed: ${msg}`);
  }
  return data as T;
}

export async function registerPartner(
  cfg: GatewayConfig,
  name: string,
  allowedSites: string[],
): Promise<RegisterResult> {
  if (!cfg.adminKey) throw new Error("adminKey required to register a partner");
  return await post<RegisterResult>(cfg, "/partner-auth/register", { name, allowed_sites: allowedSites }, {
    "x-wave-admin-key": cfg.adminKey,
  });
}

export function getToken(cfg: GatewayConfig, key: string): Promise<TokenResult> {
  return post<TokenResult>(cfg, "/partner-auth/token", { key });
}

export function emitMock(
  cfg: GatewayConfig,
  token: string,
  cardId: string,
  scenario: string,
): Promise<{ ok: boolean }> {
  return post(cfg, "/unlock-mock", { card_id: cardId, scenario }, { Authorization: `Bearer ${token}` });
}

export function readStream(
  cfg: GatewayConfig,
  token: string,
  cardId: string,
): Promise<UnlockStatus> {
  return post<UnlockStatus>(cfg, "/unlock-stream", { card_id: cardId }, {
    Authorization: `Bearer ${token}`,
  });
}

// The differentiator: full unattended unlock proof with no hardware.
// Exchanges a test key for a token, emits the scenario, reads the result back.
export async function simulate(
  cfg: GatewayConfig,
  testKey: string,
  cardId: string,
  scenario: string,
): Promise<{ before: UnlockStatus; emitted: boolean; after: UnlockStatus }> {
  const { token, mode } = await getToken(cfg, testKey);
  if (mode !== "test") throw new Error("simulate requires a test key (wave_test_*)");
  const before = await readStream(cfg, token, cardId);
  await emitMock(cfg, token, cardId, scenario);
  const after = await readStream(cfg, token, cardId);
  return { before, emitted: true, after };
}
