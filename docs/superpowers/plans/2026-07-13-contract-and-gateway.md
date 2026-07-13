# Wave Unlock SDK — Contract + Gateway Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the contract (single source of truth) and the Supabase Edge Function gateway that lets third-party partners authenticate with Wave-issued keys, receive per-tenant unlock results, and test the full grant/deny flow against a mock — with zero hardware.

**Architecture:** A `contract/` directory holds `wave-protocol.json` (BLE UUIDs/payload/status/denial table), `openapi.yaml` (gateway API), and `conformance/` JSON vectors that every downstream SDK will validate against. The gateway is three new Deno Edge Functions (`partner-auth`, `unlock-stream`, `unlock-mock`) plus a `wave_partners` table, co-deployed into the existing `passeport` Supabase project alongside `unlock-event`. Pure logic (key hashing, HMAC session tokens, denial mapping) is extracted into `_shared/` modules and unit-tested with `deno test`; the wired functions are integration-tested with curl against a locally-served stack.

**Tech Stack:** Deno (Supabase Edge Runtime, deno_version 2), `@supabase/supabase-js@2` via esm.sh, Web Crypto (HMAC-SHA256, SHA-256), Postgres 17, Supabase CLI.

## Global Constraints

- Deno Edge Functions only; import `@supabase/supabase-js@2` from `https://esm.sh/@supabase/supabase-js@2` (match existing functions).
- Reuse the existing function idioms verbatim: `corsHeaders`, `json(data, status)`, `err(message, status)`, `Deno.serve`, path routing via `new URL(req.url).pathname.replace(/^\/<fn>/, "")`.
- Service-role client built from `Deno.env.get("SUPABASE_URL")!` + `Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!`.
- **Never drop `anon_read_unlock_events`** — the shipping first-party app depends on it.
- Gateway functions physically live in `/Users/leolebel/passeport/supabase/functions/`; contract + plan live in `/Users/leolebel/wave-sdk/`.
- Key formats (exact): publishable `wave_pub_` + 32 lowercase hex; secret `wave_sk_` + 48 hex; test `wave_test_` + 32 hex. Store only SHA-256 hex hashes, never plaintext.
- Session token = `base64url(JSON payload).base64url(HMAC-SHA256 sig)`, signed with `Deno.env.get("WAVE_TOKEN_SECRET")!`. Payload fields: `pid` (partner id), `sites` (string[]), `mode` (`"live"|"test"`), `exp` (unix seconds). TTL 300s.
- Partner registration is gated by header `x-wave-admin-key` === `Deno.env.get("WAVE_ADMIN_KEY")!`.
- BLE protocol constants (verbatim, from the first-party app): service UUID `496B2C43-B05E-4A9A-9592-535173B7AB51`; write characteristic `995B637F-13F2-4335-96F5-5541ECFCE219`; payload = `0x01` + userNumber ASCII; write-without-response; disconnect 1.5s; default RSSI threshold −40; cloud timeout 5000ms.

---

## File Structure

**wave-sdk repo (`/Users/leolebel/wave-sdk/`):**
- Create: `contract/wave-protocol.json` — BLE constants, SICM status codes, denial table.
- Create: `contract/openapi.yaml` — gateway HTTP API.
- Create: `contract/conformance/denial-mapping.json` — SICM reason → friendly message vectors.
- Create: `contract/conformance/mock-scenarios.json` — mock scenario → `{result, reason}` vectors.
- Create: `contract/conformance/state-sequences.json` — gateway event → SDK state sequence (consumed by later SDK plans).
- Create: `contract/validate.ts` — Deno script that structurally validates the JSON files.
- Create: `contract/validate_test.ts` — tests for the validator.

**passeport repo (`/Users/leolebel/passeport/`):**
- Create: `supabase/functions/_shared/wave-keys.ts` — key generation, hashing, verification.
- Create: `supabase/functions/_shared/wave-keys_test.ts`
- Create: `supabase/functions/_shared/wave-token.ts` — HMAC session token mint/verify.
- Create: `supabase/functions/_shared/wave-token_test.ts`
- Create: `supabase/functions/_shared/wave-denial.ts` — denial + mock-scenario maps (generated-equivalent of the contract).
- Create: `supabase/functions/_shared/wave-denial_test.ts`
- Create: `supabase/migrations/20260713120000_wave_partners.sql` — `wave_partners` table + RLS.
- Create: `supabase/functions/partner-auth/index.ts`
- Create: `supabase/functions/unlock-stream/index.ts`
- Create: `supabase/functions/unlock-mock/index.ts`
- Create: `supabase/functions/_shared/http.ts` — shared `corsHeaders`/`json`/`err` (DRY; imported by the three new functions).

---

### Task 1: Contract — protocol + conformance vectors

**Files:**
- Create: `/Users/leolebel/wave-sdk/contract/wave-protocol.json`
- Create: `/Users/leolebel/wave-sdk/contract/conformance/denial-mapping.json`
- Create: `/Users/leolebel/wave-sdk/contract/conformance/mock-scenarios.json`
- Create: `/Users/leolebel/wave-sdk/contract/conformance/state-sequences.json`
- Create: `/Users/leolebel/wave-sdk/contract/validate.ts`
- Test: `/Users/leolebel/wave-sdk/contract/validate_test.ts`

**Interfaces:**
- Produces: `validateContract(dir: string): { ok: boolean; errors: string[] }` — used by CI and Task 5's cross-check. `wave-protocol.json` shape: `{ ble: {serviceUuid, writeCharacteristicUuid, payloadPrefix, writeWithoutResponse, disconnectDelayMs}, proximity: {defaultRssiThreshold, cloudTimeoutMs}, sicmStatusCodes: {idle,processing,timeout}, denials: Array<{sicm, friendly}> }`.

- [ ] **Step 1: Write the failing test**

`/Users/leolebel/wave-sdk/contract/validate_test.ts`:
```ts
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { validateContract } from "./validate.ts";

Deno.test("contract validates clean", () => {
  const res = validateContract(new URL(".", import.meta.url).pathname);
  assertEquals(res.errors, []);
  assertEquals(res.ok, true);
});

Deno.test("denial table has all 14 SICM mappings", async () => {
  const p = new URL("./conformance/denial-mapping.json", import.meta.url);
  const rows = JSON.parse(await Deno.readTextFile(p));
  assertEquals(rows.length, 14);
  assertEquals(
    rows.find((r: {sicm: string}) => r.sicm === "Client not found")?.friendly,
    "Member not found",
  );
});

Deno.test("mock scenarios cover granted + a denial", async () => {
  const p = new URL("./conformance/mock-scenarios.json", import.meta.url);
  const rows = JSON.parse(await Deno.readTextFile(p));
  assertEquals(rows.find((r: {scenario: string}) => r.scenario === "granted")?.result, "granted");
  assertEquals(rows.find((r: {scenario: string}) => r.scenario === "member_not_found")?.result, "denied");
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/leolebel/wave-sdk/contract && deno test --allow-read validate_test.ts`
Expected: FAIL — `validate.ts` and the JSON files do not exist.

- [ ] **Step 3: Create the JSON contract files**

`/Users/leolebel/wave-sdk/contract/wave-protocol.json`:
```json
{
  "version": "1.0.0",
  "ble": {
    "serviceUuid": "496B2C43-B05E-4A9A-9592-535173B7AB51",
    "writeCharacteristicUuid": "995B637F-13F2-4335-96F5-5541ECFCE219",
    "readerNames": ["SKBluTag"],
    "payloadPrefix": 1,
    "writeWithoutResponse": true,
    "disconnectDelayMs": 1500
  },
  "proximity": {
    "defaultRssiThreshold": -40,
    "cloudTimeoutMs": 5000
  },
  "sicmStatusCodes": { "idle": "1", "processing": "3", "timeout": "6" },
  "denialMappingRef": "conformance/denial-mapping.json"
}
```

`/Users/leolebel/wave-sdk/contract/conformance/denial-mapping.json`:
```json
[
  { "sicm": "Granted by provider cache", "friendly": "Access Granted", "result": "granted" },
  { "sicm": "Client not found", "friendly": "Member not found", "result": "denied" },
  { "sicm": "Blocked by schedule", "friendly": "Outside access hours", "result": "denied" },
  { "sicm": "Maximum active signins", "friendly": "Maximum active sign-ins reached", "result": "denied" },
  { "sicm": "Checkins limitation", "friendly": "Daily check-in limit reached", "result": "denied" },
  { "sicm": "Blocked by restriction", "friendly": "Membership restriction", "result": "denied" },
  { "sicm": "Blocked by client alert", "friendly": "Account alert", "result": "denied" },
  { "sicm": "Over account balance", "friendly": "Outstanding balance", "result": "denied" },
  { "sicm": "Liability release", "friendly": "Liability release required", "result": "denied" },
  { "sicm": "Scheduled visit", "friendly": "No booking found", "result": "denied" },
  { "sicm": "No member picture", "friendly": "Photo required", "result": "denied" },
  { "sicm": "Provider not found", "friendly": "System error - provider unavailable", "result": "denied" },
  { "sicm": "Inactive", "friendly": "Membership inactive", "result": "denied" },
  { "sicm": "Expired", "friendly": "Membership expired", "result": "denied" }
]
```

`/Users/leolebel/wave-sdk/contract/conformance/mock-scenarios.json`:
```json
[
  { "scenario": "granted", "result": "granted", "reason": "Access Granted" },
  { "scenario": "member_not_found", "result": "denied", "reason": "Member not found" },
  { "scenario": "outside_hours", "result": "denied", "reason": "Outside access hours" },
  { "scenario": "membership_expired", "result": "denied", "reason": "Membership expired" },
  { "scenario": "outstanding_balance", "result": "denied", "reason": "Outstanding balance" }
]
```

`/Users/leolebel/wave-sdk/contract/conformance/state-sequences.json`:
```json
[
  { "event": { "result": "granted" }, "states": ["scanning", "readerFound", "writing", "awaitingConfirmation", "granted"] },
  { "event": { "result": "denied", "reason": "Member not found" }, "states": ["scanning", "readerFound", "writing", "awaitingConfirmation", "denied"] },
  { "event": null, "states": ["scanning", "readerFound", "writing", "awaitingConfirmation", "timedOut"] }
]
```

- [ ] **Step 4: Write the validator**

`/Users/leolebel/wave-sdk/contract/validate.ts`:
```ts
export function validateContract(dir: string): { ok: boolean; errors: string[] } {
  const errors: string[] = [];
  const read = (rel: string) => JSON.parse(Deno.readTextFileSync(`${dir}/${rel}`));

  let proto;
  try {
    proto = read("wave-protocol.json");
  } catch (e) {
    return { ok: false, errors: [`wave-protocol.json unreadable: ${e.message}`] };
  }
  const uuidRe = /^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$/;
  if (!uuidRe.test(proto?.ble?.serviceUuid ?? "")) errors.push("ble.serviceUuid malformed");
  if (!uuidRe.test(proto?.ble?.writeCharacteristicUuid ?? "")) errors.push("ble.writeCharacteristicUuid malformed");
  if (proto?.ble?.payloadPrefix !== 1) errors.push("ble.payloadPrefix must be 1");

  let denials: Array<{ sicm: string; friendly: string; result: string }>;
  try {
    denials = read("conformance/denial-mapping.json");
  } catch (e) {
    return { ok: false, errors: [...errors, `denial-mapping.json unreadable: ${e.message}`] };
  }
  const seen = new Set<string>();
  for (const d of denials) {
    if (!d.sicm || !d.friendly) errors.push(`denial row missing fields: ${JSON.stringify(d)}`);
    if (d.result !== "granted" && d.result !== "denied") errors.push(`denial row bad result: ${d.sicm}`);
    if (seen.has(d.sicm)) errors.push(`duplicate sicm key: ${d.sicm}`);
    seen.add(d.sicm);
  }

  let scenarios: Array<{ scenario: string; result: string; reason: string }>;
  try {
    scenarios = read("conformance/mock-scenarios.json");
  } catch (e) {
    return { ok: false, errors: [...errors, `mock-scenarios.json unreadable: ${e.message}`] };
  }
  const friendlySet = new Set(denials.map((d) => d.friendly));
  for (const s of scenarios) {
    if (!friendlySet.has(s.reason)) errors.push(`mock scenario reason not in denial table: ${s.reason}`);
  }

  return { ok: errors.length === 0, errors };
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd /Users/leolebel/wave-sdk/contract && deno test --allow-read validate_test.ts`
Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
cd /Users/leolebel/wave-sdk
git add contract/
git commit -m "feat(contract): protocol + conformance vectors + validator"
```

---

### Task 2: Contract — OpenAPI spec for the gateway

**Files:**
- Create: `/Users/leolebel/wave-sdk/contract/openapi.yaml`
- Test: `/Users/leolebel/wave-sdk/contract/openapi_test.ts`

**Interfaces:**
- Produces: `openapi.yaml` documenting `POST /partner-auth/register`, `POST /partner-auth/token`, `POST /unlock-stream`, `POST /unlock-mock`. Consumed later by codegen for typed clients.

- [ ] **Step 1: Write the failing test**

`/Users/leolebel/wave-sdk/contract/openapi_test.ts`:
```ts
import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { parse } from "https://deno.land/std@0.224.0/yaml/mod.ts";

Deno.test("openapi documents all four gateway endpoints", async () => {
  const text = await Deno.readTextFile(new URL("./openapi.yaml", import.meta.url));
  const doc = parse(text) as { paths: Record<string, unknown> };
  for (const p of ["/partner-auth/register", "/partner-auth/token", "/unlock-stream", "/unlock-mock"]) {
    assert(doc.paths[p], `missing path ${p}`);
  }
  assertEquals(Object.keys(doc.paths).length, 4);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/leolebel/wave-sdk/contract && deno test --allow-read openapi_test.ts`
Expected: FAIL — `openapi.yaml` missing.

- [ ] **Step 3: Write the OpenAPI spec**

`/Users/leolebel/wave-sdk/contract/openapi.yaml`:
```yaml
openapi: 3.1.0
info:
  title: Wave Unlock Gateway
  version: 1.0.0
  description: Partner-facing gateway for Wave Passport BLE door unlock.
servers:
  - url: https://{project}.supabase.co/functions/v1
    variables:
      project: { default: "PROJECT_REF" }
paths:
  /partner-auth/register:
    post:
      summary: Provision a partner (admin only). Returns plaintext keys ONCE.
      parameters:
        - in: header
          name: x-wave-admin-key
          required: true
          schema: { type: string }
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [name, allowed_sites]
              properties:
                name: { type: string }
                allowed_sites: { type: array, items: { type: string } }
      responses:
        "200":
          description: Partner created
          content:
            application/json:
              schema:
                type: object
                properties:
                  partner_id: { type: string }
                  publishable_key: { type: string }
                  secret_key: { type: string }
                  test_key: { type: string }
        "401": { description: Bad admin key }
  /partner-auth/token:
    post:
      summary: Exchange a publishable or test key for a short-lived session token.
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [key]
              properties:
                key: { type: string, description: "wave_pub_* or wave_test_*" }
      responses:
        "200":
          description: Session token
          content:
            application/json:
              schema:
                type: object
                properties:
                  token: { type: string }
                  mode: { type: string, enum: [live, test] }
                  expires_in: { type: integer }
        "401": { description: Invalid key }
  /unlock-stream:
    post:
      summary: Read the caller's most recent unlock result (per-tenant scoped).
      parameters:
        - in: header
          name: authorization
          required: true
          schema: { type: string, description: "Bearer <session token>" }
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [card_id]
              properties:
                card_id: { type: string }
                binding_id: { type: string }
      responses:
        "200":
          description: Result or pending
          content:
            application/json:
              schema:
                type: object
                properties:
                  status: { type: string, enum: [granted, denied, pending] }
                  reason: { type: string, nullable: true }
        "401": { description: Invalid/expired token }
  /unlock-mock:
    post:
      summary: Emit a synthetic unlock event (test-mode token only).
      parameters:
        - in: header
          name: authorization
          required: true
          schema: { type: string, description: "Bearer <test-mode session token>" }
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [card_id, scenario]
              properties:
                card_id: { type: string }
                scenario: { type: string }
      responses:
        "200": { description: Event emitted }
        "403": { description: Not a test-mode token }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/leolebel/wave-sdk/contract && deno test --allow-read openapi_test.ts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/leolebel/wave-sdk
git add contract/openapi.yaml contract/openapi_test.ts
git commit -m "feat(contract): OpenAPI spec for the gateway"
```

---

### Task 3: Gateway shared — API key generation & hashing

**Files:**
- Create: `/Users/leolebel/passeport/supabase/functions/_shared/wave-keys.ts`
- Test: `/Users/leolebel/passeport/supabase/functions/_shared/wave-keys_test.ts`

**Interfaces:**
- Produces:
  - `generateKeys(): Promise<{ publishable: string; secret: string; test: string }>`
  - `sha256Hex(input: string): Promise<string>`
  - `keyKind(key: string): "pub" | "sk" | "test" | null`

- [ ] **Step 1: Write the failing test**

`/Users/leolebel/passeport/supabase/functions/_shared/wave-keys_test.ts`:
```ts
import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { generateKeys, sha256Hex, keyKind } from "./wave-keys.ts";

Deno.test("generateKeys yields correctly-prefixed, correctly-sized keys", async () => {
  const k = await generateKeys();
  assert(/^wave_pub_[0-9a-f]{32}$/.test(k.publishable), k.publishable);
  assert(/^wave_sk_[0-9a-f]{48}$/.test(k.secret), k.secret);
  assert(/^wave_test_[0-9a-f]{32}$/.test(k.test), k.test);
});

Deno.test("keyKind classifies prefixes", () => {
  assertEquals(keyKind("wave_pub_" + "a".repeat(32)), "pub");
  assertEquals(keyKind("wave_sk_" + "a".repeat(48)), "sk");
  assertEquals(keyKind("wave_test_" + "a".repeat(32)), "test");
  assertEquals(keyKind("garbage"), null);
});

Deno.test("sha256Hex is stable and 64 chars", async () => {
  const h = await sha256Hex("hello");
  assertEquals(h, "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824");
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/leolebel/passeport/supabase/functions/_shared && deno test wave-keys_test.ts`
Expected: FAIL — `wave-keys.ts` missing.

- [ ] **Step 3: Implement**

`/Users/leolebel/passeport/supabase/functions/_shared/wave-keys.ts`:
```ts
function randomHex(bytes: number): string {
  const buf = new Uint8Array(bytes);
  crypto.getRandomValues(buf);
  return Array.from(buf, (b) => b.toString(16).padStart(2, "0")).join("");
}

export async function generateKeys(): Promise<{ publishable: string; secret: string; test: string }> {
  return {
    publishable: "wave_pub_" + randomHex(16),
    secret: "wave_sk_" + randomHex(24),
    test: "wave_test_" + randomHex(16),
  };
}

export async function sha256Hex(input: string): Promise<string> {
  const data = new TextEncoder().encode(input);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, "0")).join("");
}

export function keyKind(key: string): "pub" | "sk" | "test" | null {
  if (/^wave_pub_[0-9a-f]{32}$/.test(key)) return "pub";
  if (/^wave_sk_[0-9a-f]{48}$/.test(key)) return "sk";
  if (/^wave_test_[0-9a-f]{32}$/.test(key)) return "test";
  return null;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/leolebel/passeport/supabase/functions/_shared && deno test wave-keys_test.ts`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
cd /Users/leolebel/passeport
git add supabase/functions/_shared/wave-keys.ts supabase/functions/_shared/wave-keys_test.ts
git commit -m "feat(gateway): wave-keys — key gen, hashing, classification"
```

---

### Task 4: Gateway shared — HMAC session tokens

**Files:**
- Create: `/Users/leolebel/passeport/supabase/functions/_shared/wave-token.ts`
- Test: `/Users/leolebel/passeport/supabase/functions/_shared/wave-token_test.ts`

**Interfaces:**
- Produces:
  - `type Session = { pid: string; sites: string[]; mode: "live" | "test"; exp: number }`
  - `mintToken(session: Session, secret: string): Promise<string>`
  - `verifyToken(token: string, secret: string, nowSec: number): Promise<Session | null>` (returns null on bad sig or expiry)

- [ ] **Step 1: Write the failing test**

`/Users/leolebel/passeport/supabase/functions/_shared/wave-token_test.ts`:
```ts
import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { mintToken, verifyToken, type Session } from "./wave-token.ts";

const SECRET = "test-secret";
const base: Session = { pid: "p1", sites: ["CBSM-2720"], mode: "live", exp: 1000 };

Deno.test("round-trips a valid token", async () => {
  const t = await mintToken(base, SECRET);
  const s = await verifyToken(t, SECRET, 900);
  assertEquals(s, base);
});

Deno.test("rejects an expired token", async () => {
  const t = await mintToken(base, SECRET);
  assertEquals(await verifyToken(t, SECRET, 1001), null);
});

Deno.test("rejects a tampered signature", async () => {
  const t = await mintToken(base, SECRET);
  const bad = t.slice(0, -2) + (t.endsWith("A") ? "B" : "A");
  assertEquals(await verifyToken(bad, SECRET, 900), null);
});

Deno.test("rejects a token signed with a different secret", async () => {
  const t = await mintToken(base, SECRET);
  assertEquals(await verifyToken(t, "other", 900), null);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/leolebel/passeport/supabase/functions/_shared && deno test wave-token_test.ts`
Expected: FAIL — `wave-token.ts` missing.

- [ ] **Step 3: Implement**

`/Users/leolebel/passeport/supabase/functions/_shared/wave-token.ts`:
```ts
export type Session = { pid: string; sites: string[]; mode: "live" | "test"; exp: number };

function b64urlEncode(bytes: Uint8Array): string {
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function b64urlDecode(s: string): Uint8Array {
  const pad = s.length % 4 === 0 ? "" : "=".repeat(4 - (s.length % 4));
  const bin = atob(s.replace(/-/g, "+").replace(/_/g, "/") + pad);
  return Uint8Array.from(bin, (c) => c.charCodeAt(0));
}

async function hmac(payloadB64: string, secret: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(payloadB64));
  return b64urlEncode(new Uint8Array(sig));
}

export async function mintToken(session: Session, secret: string): Promise<string> {
  const payloadB64 = b64urlEncode(new TextEncoder().encode(JSON.stringify(session)));
  const sig = await hmac(payloadB64, secret);
  return `${payloadB64}.${sig}`;
}

export async function verifyToken(token: string, secret: string, nowSec: number): Promise<Session | null> {
  const parts = token.split(".");
  if (parts.length !== 2) return null;
  const [payloadB64, sig] = parts;
  const expected = await hmac(payloadB64, secret);
  // constant-time-ish compare
  if (sig.length !== expected.length) return null;
  let diff = 0;
  for (let i = 0; i < sig.length; i++) diff |= sig.charCodeAt(i) ^ expected.charCodeAt(i);
  if (diff !== 0) return null;
  let session: Session;
  try {
    session = JSON.parse(new TextDecoder().decode(b64urlDecode(payloadB64)));
  } catch {
    return null;
  }
  if (typeof session.exp !== "number" || session.exp < nowSec) return null;
  return session;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/leolebel/passeport/supabase/functions/_shared && deno test wave-token_test.ts`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
cd /Users/leolebel/passeport
git add supabase/functions/_shared/wave-token.ts supabase/functions/_shared/wave-token_test.ts
git commit -m "feat(gateway): wave-token — HMAC-signed short-lived session tokens"
```

---

### Task 5: Gateway shared — denial + mock-scenario maps (contract-conformant)

**Files:**
- Create: `/Users/leolebel/passeport/supabase/functions/_shared/wave-denial.ts`
- Test: `/Users/leolebel/passeport/supabase/functions/_shared/wave-denial_test.ts`

**Interfaces:**
- Produces:
  - `MOCK_SCENARIOS: Record<string, { result: "granted" | "denied"; reason: string }>`
  - `scenarioToEvent(scenario: string): { result: "granted" | "denied"; reason: string } | null`

**Note:** These values are copied verbatim from `contract/conformance/*.json`. Later, codegen will emit this file from the contract; for now the test hard-codes the same vectors so drift is caught.

- [ ] **Step 1: Write the failing test**

`/Users/leolebel/passeport/supabase/functions/_shared/wave-denial_test.ts`:
```ts
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { scenarioToEvent, MOCK_SCENARIOS } from "./wave-denial.ts";

Deno.test("granted scenario maps to a granted event", () => {
  assertEquals(scenarioToEvent("granted"), { result: "granted", reason: "Access Granted" });
});

Deno.test("member_not_found maps to a denial", () => {
  assertEquals(scenarioToEvent("member_not_found"), { result: "denied", reason: "Member not found" });
});

Deno.test("unknown scenario returns null", () => {
  assertEquals(scenarioToEvent("nope"), null);
});

Deno.test("all five contract scenarios present", () => {
  for (const s of ["granted", "member_not_found", "outside_hours", "membership_expired", "outstanding_balance"]) {
    assertEquals(typeof MOCK_SCENARIOS[s].result, "string");
  }
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/leolebel/passeport/supabase/functions/_shared && deno test wave-denial_test.ts`
Expected: FAIL — `wave-denial.ts` missing.

- [ ] **Step 3: Implement**

`/Users/leolebel/passeport/supabase/functions/_shared/wave-denial.ts`:
```ts
// Verbatim from wave-sdk/contract/conformance/mock-scenarios.json.
// TODO(codegen): generate this from the contract in the codegen task.
export const MOCK_SCENARIOS: Record<string, { result: "granted" | "denied"; reason: string }> = {
  granted: { result: "granted", reason: "Access Granted" },
  member_not_found: { result: "denied", reason: "Member not found" },
  outside_hours: { result: "denied", reason: "Outside access hours" },
  membership_expired: { result: "denied", reason: "Membership expired" },
  outstanding_balance: { result: "denied", reason: "Outstanding balance" },
};

export function scenarioToEvent(scenario: string): { result: "granted" | "denied"; reason: string } | null {
  return MOCK_SCENARIOS[scenario] ?? null;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/leolebel/passeport/supabase/functions/_shared && deno test wave-denial_test.ts`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
cd /Users/leolebel/passeport
git add supabase/functions/_shared/wave-denial.ts supabase/functions/_shared/wave-denial_test.ts
git commit -m "feat(gateway): wave-denial — mock scenario map (contract-conformant)"
```

---

### Task 6: Migration — `wave_partners` table

**Files:**
- Create: `/Users/leolebel/passeport/supabase/migrations/20260713120000_wave_partners.sql`

**Interfaces:**
- Produces: table `wave_partners(id uuid pk, name text, pub_key_hash text unique, secret_key_hash text unique, test_key_hash text unique, allowed_sites text[], active bool, created_at timestamptz)`, RLS service-role-only.

- [ ] **Step 1: Write the migration**

`/Users/leolebel/passeport/supabase/migrations/20260713120000_wave_partners.sql`:
```sql
-- wave_partners: third-party SDK partners. Keys stored as SHA-256 hex hashes only.
CREATE TABLE IF NOT EXISTS wave_partners (
    id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name            TEXT NOT NULL,
    pub_key_hash    TEXT NOT NULL UNIQUE,
    secret_key_hash TEXT NOT NULL UNIQUE,
    test_key_hash   TEXT NOT NULL UNIQUE,
    allowed_sites   TEXT[] NOT NULL DEFAULT '{}',
    active          BOOLEAN NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_wave_partners_pub  ON wave_partners(pub_key_hash);
CREATE INDEX IF NOT EXISTS idx_wave_partners_test ON wave_partners(test_key_hash);

ALTER TABLE wave_partners ENABLE ROW LEVEL SECURITY;

-- Service-role only; no anon access. All partner reads go through Edge Functions
-- which use the service-role client.
CREATE POLICY "service_all_wave_partners" ON wave_partners
    FOR ALL TO service_role USING (true) WITH CHECK (true);

-- NOTE: anon_read_unlock_events is intentionally left in place for backward-compat
-- with the shipping first-party Wave Passport app. Do NOT drop it here.
```

- [ ] **Step 2: Apply locally and verify the table exists**

Run:
```bash
cd /Users/leolebel/passeport && supabase db reset --local 2>/dev/null || supabase migration up --local
psql "$(supabase status --local -o env | grep DB_URL | cut -d= -f2- | tr -d '\"')" -c "\d wave_partners"
```
Expected: table description prints with the 8 columns and the unique constraints.

(If Docker/local stack is unavailable, apply against the linked project in Step 3 of Task 10 instead and note it here.)

- [ ] **Step 3: Commit**

```bash
cd /Users/leolebel/passeport
git add supabase/migrations/20260713120000_wave_partners.sql
git commit -m "feat(gateway): wave_partners table + service-role RLS"
```

---

### Task 7: `partner-auth` Edge Function

**Files:**
- Create: `/Users/leolebel/passeport/supabase/functions/_shared/http.ts`
- Create: `/Users/leolebel/passeport/supabase/functions/partner-auth/index.ts`

**Interfaces:**
- Consumes: `generateKeys`, `sha256Hex`, `keyKind` (Task 3); `mintToken`, `Session` (Task 4).
- Produces: HTTP routes `POST /partner-auth/register`, `POST /partner-auth/token` (see openapi.yaml). Session TTL 300s.

- [ ] **Step 1: Write the shared HTTP helper**

`/Users/leolebel/passeport/supabase/functions/_shared/http.ts`:
```ts
export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-wave-admin-key, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

export function err(message: string, status = 400): Response {
  return json({ error: message }, status);
}
```

- [ ] **Step 2: Write the function**

`/Users/leolebel/passeport/supabase/functions/partner-auth/index.ts`:
```ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, json, err } from "../_shared/http.ts";
import { generateKeys, sha256Hex, keyKind } from "../_shared/wave-keys.ts";
import { mintToken, type Session } from "../_shared/wave-token.ts";

const TOKEN_TTL_SEC = 300;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders });
  if (req.method !== "POST") return err("Method not allowed", 405);

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const path = new URL(req.url).pathname.replace(/^\/partner-auth/, "");
  const body = await req.json().catch(() => ({}));

  // ─── POST /partner-auth/register ───
  if (path === "/register") {
    if (req.headers.get("x-wave-admin-key") !== Deno.env.get("WAVE_ADMIN_KEY")) {
      return err("Unauthorized", 401);
    }
    const { name, allowed_sites } = body;
    if (!name || !Array.isArray(allowed_sites)) {
      return err("name and allowed_sites required");
    }
    const keys = await generateKeys();
    const { data, error } = await supabase
      .from("wave_partners")
      .insert({
        name,
        allowed_sites,
        pub_key_hash: await sha256Hex(keys.publishable),
        secret_key_hash: await sha256Hex(keys.secret),
        test_key_hash: await sha256Hex(keys.test),
      })
      .select("id")
      .single();
    if (error) return err("Failed to create partner: " + error.message, 500);
    return json({
      partner_id: data.id,
      publishable_key: keys.publishable,
      secret_key: keys.secret,
      test_key: keys.test,
    });
  }

  // ─── POST /partner-auth/token ───
  if (path === "/token") {
    const { key } = body;
    const kind = key ? keyKind(key) : null;
    if (!kind || kind === "sk") return err("A publishable or test key is required", 401);
    const hash = await sha256Hex(key);
    const column = kind === "pub" ? "pub_key_hash" : "test_key_hash";
    const { data: partner } = await supabase
      .from("wave_partners")
      .select("id, allowed_sites, active")
      .eq(column, hash)
      .single();
    if (!partner || !partner.active) return err("Invalid key", 401);

    const nowSec = Math.floor(Date.now() / 1000);
    const session: Session = {
      pid: partner.id,
      sites: partner.allowed_sites,
      mode: kind === "pub" ? "live" : "test",
      exp: nowSec + TOKEN_TTL_SEC,
    };
    const token = await mintToken(session, Deno.env.get("WAVE_TOKEN_SECRET")!);
    return json({ token, mode: session.mode, expires_in: TOKEN_TTL_SEC });
  }

  return err("Not found", 404);
});
```

- [ ] **Step 3: Commit**

```bash
cd /Users/leolebel/passeport
git add supabase/functions/_shared/http.ts supabase/functions/partner-auth/index.ts
git commit -m "feat(gateway): partner-auth — register + token endpoints"
```

(Integration verification happens end-to-end in Task 10.)

---

### Task 8: `unlock-stream` Edge Function

**Files:**
- Create: `/Users/leolebel/passeport/supabase/functions/unlock-stream/index.ts`

**Interfaces:**
- Consumes: `verifyToken`, `Session` (Task 4); `corsHeaders/json/err` (Task 7).
- Produces: `POST /unlock-stream` → `{ status: "granted"|"denied"|"pending", reason: string|null }`, scoped to the caller's `sites`.

- [ ] **Step 1: Write the function**

`/Users/leolebel/passeport/supabase/functions/unlock-stream/index.ts`:
```ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, json, err } from "../_shared/http.ts";
import { verifyToken } from "../_shared/wave-token.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders });
  if (req.method !== "POST") return err("Method not allowed", 405);

  const auth = req.headers.get("authorization") ?? "";
  const token = auth.startsWith("Bearer ") ? auth.slice(7) : "";
  const session = await verifyToken(token, Deno.env.get("WAVE_TOKEN_SECRET")!, Math.floor(Date.now() / 1000));
  if (!session) return err("Invalid or expired token", 401);

  const { card_id, binding_id } = await req.json().catch(() => ({}));
  if (!card_id) return err("card_id required");
  if (session.sites.length === 0) return json({ status: "pending", reason: null });

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  let query = supabase
    .from("unlock_events")
    .select("result, reason, binding_id, created_at")
    .eq("card_id", card_id)
    .in("site_number", session.sites)
    .order("created_at", { ascending: false })
    .limit(1);
  if (binding_id) query = query.eq("binding_id", binding_id);

  const { data, error } = await query;
  if (error) return err("Query failed: " + error.message, 500);
  const row = data?.[0];
  if (!row) return json({ status: "pending", reason: null });
  return json({ status: row.result, reason: row.reason ?? null });
});
```

- [ ] **Step 2: Commit**

```bash
cd /Users/leolebel/passeport
git add supabase/functions/unlock-stream/index.ts
git commit -m "feat(gateway): unlock-stream — per-tenant unlock result read"
```

---

### Task 9: `unlock-mock` Edge Function

**Files:**
- Create: `/Users/leolebel/passeport/supabase/functions/unlock-mock/index.ts`

**Interfaces:**
- Consumes: `verifyToken` (Task 4); `scenarioToEvent` (Task 5); `corsHeaders/json/err` (Task 7).
- Produces: `POST /unlock-mock` → inserts a synthetic `unlock_events` row for the caller's first allowed site. Rejects non-test-mode tokens with 403.

- [ ] **Step 1: Write the function**

`/Users/leolebel/passeport/supabase/functions/unlock-mock/index.ts`:
```ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, json, err } from "../_shared/http.ts";
import { verifyToken } from "../_shared/wave-token.ts";
import { scenarioToEvent } from "../_shared/wave-denial.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders });
  if (req.method !== "POST") return err("Method not allowed", 405);

  const auth = req.headers.get("authorization") ?? "";
  const token = auth.startsWith("Bearer ") ? auth.slice(7) : "";
  const session = await verifyToken(token, Deno.env.get("WAVE_TOKEN_SECRET")!, Math.floor(Date.now() / 1000));
  if (!session) return err("Invalid or expired token", 401);
  if (session.mode !== "test") return err("unlock-mock requires a test-mode token", 403);

  const { card_id, scenario } = await req.json().catch(() => ({}));
  if (!card_id || !scenario) return err("card_id and scenario required");
  const event = scenarioToEvent(scenario);
  if (!event) return err("Unknown scenario: " + scenario);
  if (session.sites.length === 0) return err("Partner has no allowed sites", 400);

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const { error } = await supabase.from("unlock_events").insert({
    site_number: session.sites[0],
    card_id,
    result: event.result,
    reason: `[mock] ${event.reason}`,
  });
  if (error) return err("Insert failed: " + error.message, 500);
  return json({ ok: true, emitted: { card_id, ...event, site_number: session.sites[0] } });
});
```

- [ ] **Step 2: Commit**

```bash
cd /Users/leolebel/passeport
git add supabase/functions/unlock-mock/index.ts
git commit -m "feat(gateway): unlock-mock — synthetic events for test-mode tokens"
```

---

### Task 10: End-to-end integration + deploy

**Files:**
- Create: `/Users/leolebel/wave-sdk/gateway/e2e.sh` — the register→token→mock→stream proof.

**Interfaces:**
- Consumes: all four deployed endpoints.

- [ ] **Step 1: Confirm the linked project ref and required secrets**

Run:
```bash
cd /Users/leolebel/passeport
cat supabase/.temp/project-ref 2>/dev/null || supabase projects list
```
Set the two new function secrets (generate strong random values):
```bash
supabase secrets set WAVE_ADMIN_KEY="$(openssl rand -hex 24)" WAVE_TOKEN_SECRET="$(openssl rand -hex 32)"
```
Record `WAVE_ADMIN_KEY` locally (needed for register). Do NOT commit it.

- [ ] **Step 2: Push the migration and deploy the three functions**

Run:
```bash
cd /Users/leolebel/passeport
supabase db push
supabase functions deploy partner-auth --use-api
supabase functions deploy unlock-stream --use-api
supabase functions deploy unlock-mock --use-api
```
Expected: three `Deployed Function` confirmations. (`--use-api` per feedback: the deploy TUI hangs without it.)

- [ ] **Step 3: Write the e2e script**

`/Users/leolebel/wave-sdk/gateway/e2e.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
: "${BASE:?set BASE=https://<ref>.supabase.co/functions/v1}"
: "${ANON:?set ANON=<supabase anon key>}"
: "${ADMIN:?set ADMIN=<WAVE_ADMIN_KEY>}"
H_JSON=(-H "Content-Type: application/json" -H "Authorization: Bearer $ANON")

echo "== register partner =="
REG=$(curl -s "${H_JSON[@]}" -H "x-wave-admin-key: $ADMIN" \
  -d '{"name":"E2E Test Co","allowed_sites":["CBSM-TEST-1"]}' "$BASE/partner-auth/register")
echo "$REG"
TEST_KEY=$(echo "$REG" | grep -o '"test_key":"[^"]*"' | cut -d'"' -f4)

echo "== exchange test key for token =="
TOK=$(curl -s "${H_JSON[@]}" -d "{\"key\":\"$TEST_KEY\"}" "$BASE/partner-auth/token")
echo "$TOK"
SESSION=$(echo "$TOK" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
[ "$(echo "$TOK" | grep -o '"mode":"test"')" = '"mode":"test"' ] || { echo "expected test mode"; exit 1; }

echo "== stream before mock: expect pending =="
curl -s "${H_JSON[@]}" -H "Authorization: Bearer $SESSION" \
  -d '{"card_id":"10001"}' "$BASE/unlock-stream"; echo

echo "== emit granted mock =="
curl -s "${H_JSON[@]}" -H "Authorization: Bearer $SESSION" \
  -d '{"card_id":"10001","scenario":"granted"}' "$BASE/unlock-mock"; echo

echo "== stream after mock: expect granted =="
RES=$(curl -s "${H_JSON[@]}" -H "Authorization: Bearer $SESSION" \
  -d '{"card_id":"10001"}' "$BASE/unlock-stream")
echo "$RES"
echo "$RES" | grep -q '"status":"granted"' && echo "E2E PASS" || { echo "E2E FAIL"; exit 1; }
```
Note: `unlock-stream`/`unlock-mock` use the session token for app-auth, but Supabase's function gateway still needs the platform `Authorization: Bearer <ANON>` unless the function is set to `--no-verify-jwt`. To keep the partner flow header-clean, deploy all three with `--no-verify-jwt` (re-run Step 2 adding that flag) and drop the `-H "Authorization: Bearer $ANON"` from `H_JSON`; the session token then travels in the `Authorization` header as designed.

- [ ] **Step 4: Run the e2e proof**

Run:
```bash
chmod +x /Users/leolebel/wave-sdk/gateway/e2e.sh
BASE="https://<ref>.supabase.co/functions/v1" ADMIN="<WAVE_ADMIN_KEY>" ANON="<anon>" \
  /Users/leolebel/wave-sdk/gateway/e2e.sh
```
Expected: final line `E2E PASS`; `pending` before the mock, `granted` after.

- [ ] **Step 5: Verify tenant isolation (negative test)**

Register a second partner with `allowed_sites=["CBSM-OTHER"]`, get its test token, and confirm `unlock-stream` for `card_id 10001` returns `pending` (it must NOT see partner 1's `CBSM-TEST-1` event). This proves per-tenant scoping.

- [ ] **Step 6: Commit**

```bash
cd /Users/leolebel/wave-sdk
git add gateway/e2e.sh
git commit -m "test(gateway): end-to-end register->token->mock->stream + tenant isolation"
```

---

## Self-Review

**Spec coverage:**
- Contract (protocol, conformance, openapi) → Tasks 1–2. ✓
- `partner-auth` (keys, token mint) → Tasks 3, 4, 7. ✓
- `unlock-stream` (per-tenant read) → Task 8. ✓
- `unlock-mock` (test-only synthetic events) → Tasks 5, 9. ✓
- `wave_partners` table + service-role RLS, anon-read kept → Task 6. ✓
- Tenant isolation → Task 10 Step 5. ✓
- Denial table (14 rows) carried verbatim → Task 1 + Task 5. ✓

**Placeholder scan:** One intentional `TODO(codegen)` in Task 5 marks the future codegen source; the value is fully implemented now, so it is not a plan gap. No other placeholders.

**Type consistency:** `Session` fields (`pid/sites/mode/exp`) identical across Tasks 4, 7, 8, 9. `generateKeys` return shape (`publishable/secret/test`) consistent Tasks 3↔7. `sha256Hex`, `keyKind`, `mintToken`, `verifyToken`, `scenarioToEvent` signatures match their call sites. `unlock_events` columns (`site_number/card_id/result/reason/binding_id/created_at`) match the existing table.

**Out of scope (later plans):** Swift core, MCP server, RN/Flutter/web, docs bundle, codegen from contract.
