# Wave Unlock SDK — Design Spec

**Date:** 2026-07-13
**Status:** Approved direction, pending spec review
**Owner:** Leo Lebel

## 1. Purpose

Third-party "API providers" (gym-management platforms, access-control apps, member
apps) want to embed Wave Passport's BLE door unlock into their own applications.
Today the unlock logic lives only inside the first-party Wave Passport iOS/watchOS/
Android apps. This project extracts that logic into a distributable, multi-platform
**SDK** with an **MCP server as the primary integration channel**, so that both human
developers and AI coding agents can wire up a working door unlock in minutes.

### Success criteria

- A partner developer (or their AI agent) goes from zero to a working unlock button
  against a **mock reader** in under 10 minutes, no hardware, no support ticket.
- A single place to change the BLE protocol or cloud contract; all platforms stay in
  sync via generated code + shared conformance vectors.
- An AI agent can complete the integration **unattended** — scaffold, configure,
  self-diagnose, and test the full grant/deny flow — using only the MCP server.
- Partner credentials are isolated per-tenant; no partner ever touches Wave's raw
  Supabase/infra.

### Non-goals (YAGNI)

- Not shipping BLE code over MCP (impossible — BLE runs in the partner's app binary).
- Not building a partner billing/portal UI in v1 (keys are issued via MCP + a minimal
  admin path).
- Not supporting background BLE on web (Web Bluetooth is foreground-only; explicitly a
  limited tier).
- Not re-implementing the SICM/BBB bridge — that stays as-is; the SDK consumes its
  cloud events.

## 2. What the SDK wraps

The unlock is a 5-step pipeline, not a single BLE write. The SDK hides all five behind
one call and streams typed states:

1. **Scan** for the reader — match name `SKBluTag` OR service UUID
   `496B2C43-B05E-4A9A-9592-535173B7AB51`.
2. **Proximity gate** — RSSI vs. site threshold (admin-controlled, synced from cloud).
3. **Write** credential — characteristic `995B637F-13F2-4335-96F5-5541ECFCE219`,
   write-without-response, payload `0x01` + userNumber as ASCII. Treat write as
   immediate success; do NOT wait for a BLE notify (causes lockup). Disconnect after 1.5s.
4. **Await cloud feedback** — poll/subscribe the gateway for the unlock result event
   keyed by credential token; 5s timeout → "Waiting for confirmation…".
5. **Surface result** — map SICM internal reasons to human-readable messages (14-entry
   denial table) into a typed `UnlockResult`.

Public happy-path API (per platform, idiomatic):

```
Wave.configure(apiKey: "wave_pub_...")
for await state in Wave.unlock() {
    // .scanning, .readerFound(rssi), .tooFar, .writing,
    // .awaitingConfirmation, .granted, .denied(reason), .timedOut, .error
}
```

Everything above the happy path (proximity tuning, custom UI, multi-site) is opt-in.

## 3. Architecture — Approach C (native BLE cores, generated contract)

BLE transport is inherently native (CoreBluetooth / Android BLE / Web Bluetooth) and
cannot be meaningfully shared. So we share the *contract*, not the transport.

```
                         ┌─────────────────────────────────────────┐
                         │   Single source of truth (this repo)     │
                         │  • openapi.yaml  (gateway API)           │
                         │  • wave-protocol.json (UUIDs, payload,   │
                         │    status codes, denial-message table)   │
                         │  • conformance/*.json (test vectors)     │
                         │  • docs → llms.txt / llms-full.txt       │
                         └───────────────┬─────────────────────────┘
                        code-gen +       │        docs build
             conformance vectors ────────┼───────────────────────────
        ┌──────────────┬─────────────────┼──────────────┬────────────┐
        ▼              ▼                 ▼               ▼            ▼
   Swift core     Kotlin core       Gateway client   Web (JS,     Wave MCP
   (CoreBluetooth) (Android BLE)    types (all langs) foreground   server
        │              │             generated         only)      (npx)
        ├── RN bridge ─┤                                            │
        └── Flutter ───┘                                    PRIMARY CHANNEL
```

### 3.1 Components

- **Swift core** (`WaveUnlock`, SPM) — owns CoreBluetooth + protocol state machine +
  gateway client. Ships the drop-in `WaveUnlockButton` (SwiftUI) on top. watchOS target
  included (reuses the core; credential synced via WatchConnectivity as today).
- **Kotlin core** (`wave-unlock`, Maven/AAR) — owns Android BLE + foreground service +
  protocol state machine. Ships a Compose `WaveUnlockButton`.
- **React Native package** (`@wave/unlock-react-native`, npm) — thin TurboModule bridge
  over the two native cores. Exposes JS API + `<WaveUnlockButton />`. **Not** a
  reimplementation.
- **Flutter plugin** (`wave_unlock`, pub.dev) — thin platform-channel bridge over the
  native cores. Dart API + `WaveUnlockButton` widget.
- **Web tier** (`@wave/unlock-web`, npm) — Web Bluetooth, **foreground-only**, explicitly
  labeled limited. Same typed state stream; no background, no watchOS-style persistence.
- **Contract** — `openapi.yaml` + `wave-protocol.json` + `conformance/`. Everything
  language-specific (gateway HTTP client, request/response types, error taxonomy, the
  denial table) is **generated** from these. A protocol change = edit spec → regenerate →
  all platforms updated.
- **Conformance vectors** — shared JSON fixtures ("given this SICM log line / this
  gateway event, the SDK must emit this state sequence"). Every platform runs them in CI.
  This is what keeps 5 implementations honest without merging them.

### 3.2 Cloud gateway — Supabase Edge Functions

The gateway extends the **existing Supabase Edge Functions** (project
`zuijamqvgxvajvhrdnlx`, current `unlock-event` function) rather than standing up new
infrastructure. New/extended functions form the partner-facing API surface:

- **`unlock-event`** (existing) — unchanged ingest path from the BBB `bridge_v3.py` →
  `unlock_events`. Reused as-is.
- **`partner-auth`** (new) — validates Wave-issued API keys and mints short-lived
  unlock-session tokens. `wave_pub_*` (publishable, safe in-app, scoped to a partner +
  its sites) and `wave_sk_*` (secret, server-side, for provisioning via `wave_register_app`).
- **`unlock-stream`** (new) — the SDK's per-tenant read endpoint; takes a session token,
  returns the unlock-result event for the caller's credential/site only. Wraps the
  Realtime subscription + HTTP-poll fallback the app uses today, scoped by tenant so
  partners never see each other's events.
- **`unlock-mock`** (new) — `wave_simulate_unlock` scenarios hit this endpoint; it emits
  synthetic grant/deny events (mapped to the denial table) for a **test key only**, so
  integration is testable with no hardware. Guarded to reject `wave_pub_*`/live keys.

Supporting schema (same Supabase project):

- **`partners`** table — partner record, hashed API keys, allowed site set. RLS: service-
  write, no anon read.
- **Multi-tenancy** — every partner-facing function scopes by partner + site set;
  partners read only through `unlock-stream`, never the raw table. NOTE: the existing
  `anon_read_unlock_events` policy is **kept** for backward-compat — the shipping
  first-party Wave Passport app polls `unlock_events` directly through it. Tightening
  that policy is a deliberate future migration, only after the first-party app also
  moves onto the gateway. Do not drop it in this phase.
- **Deploy home** — the gateway Edge Functions physically live in
  `passeport/supabase/functions/` (co-deployed with `unlock-event`, sharing the DB and
  `unlock_events`). The wave-sdk `gateway/` folder is a logical grouping in the spec;
  the deployable code lands in the passeport project.
- **Rate limiting** — per-key limits enforced in `partner-auth` / `unlock-stream`
  (token bucket in a small `rate_limits` table or Supabase's built-in limits).

The BBB → `unlock_events` path is untouched; the new functions read from it and
re-project per tenant.

## 4. MCP server — the primary channel

Distributed as `npx @wave/mcp` with a one-line Claude Code / Cursor config snippet.
A partner adds the server, tells their agent *"add Wave door unlock,"* and the agent
does the integration through these tools. The MCP server operates at **build/integration
time**; it never runs BLE.

| Tool | Purpose |
|---|---|
| `wave_docs(topic?)` | Serves `llms-full.txt` or a focused slice — the agent's knowledge source. |
| `wave_scaffold(platform, style)` | Writes a working starter into the project (correct dependency line, entitlements, minimal wiring). `style` = headless \| drop-in. |
| `wave_snippet(platform, feature)` | Version-pinned exact code for one feature (unlock button, state handling, proximity UI). |
| `wave_register_app(partner, sites)` | Provisions the partner in the gateway; returns publishable + test keys. Auth-gated by a partner account token. |
| `wave_validate_config(config)` | Validates key, bundle IDs, entitlements, permissions. |
| `wave_doctor(project_path)` | Scans the project; reports what's missing (Info.plist `NSBluetoothAlwaysUsageDescription`, iOS background modes, Android `BLUETOOTH_SCAN/CONNECT`, unset key). The "why isn't it working" answer. |
| `wave_simulate_unlock(scenario)` | Drives the gateway mock to emit granted/denied events; agent tests the full state stream with no reader. Scenarios map to the denial table. |
| `wave_changelog(from_version)` | Migration guidance between SDK versions. |

**Why this is the differentiator:** `doctor` + `simulate` let an AI agent integrate,
self-diagnose, and test end-to-end unattended. The native binaries still flow through
SPM/Maven/npm/pub.dev; the MCP server orchestrates which dependency to add and how to
wire it, always in sync with the installed SDK version.

### 4.1 AI-builder support surface (beyond the MCP server)

- **`llms.txt` + `llms-full.txt`** at the docs root — full SDK surface as one flat,
  agent-ingestible file.
- **Typed everything + JSON Schema** for every config object — agents write correct code
  first try.
- **One-file example repos per platform**, each with a `CLAUDE.md`/`AGENTS.md` telling an
  agent exactly how to wire it: "clone, set key, run."
- **Mock mode** (`Wave.mock()` in-SDK, plus `wave_simulate_unlock` via MCP) — full flow
  with no hardware.

## 5. Error handling

- Typed error taxonomy generated from the contract; same categories across platforms:
  `permissionDenied`, `bluetoothOff`, `readerNotFound`, `tooFar`, `writeFailed`,
  `network`, `auth`, `timedOut`, `denied(reason)`.
- BLE quirks encoded once in the cores per the hard-won lessons: never wait for notify
  after write; ignore SKBluTag status "6"; 5s cloud timeout → orange "awaiting", not a
  false green; ambient re-scan with 0.3s restart delay.
- Offline: BLE unlock still works (SICM cache); no cloud feedback → `awaitingConfirmation`
  then `timedOut`. Documented, not an error state that blocks the door.
- `wave_doctor` surfaces the top *integration-time* errors before they ever reach runtime.

## 6. Testing

- **Conformance vectors** — shared JSON fixtures run by every platform's test suite in CI;
  the gate that keeps the 5 implementations behaviorally identical.
- **Native unit tests** per core (state machine, RSSI gating, denial mapping).
- **Mock-mode integration tests** — full happy path + each denial scenario via the gateway
  mock, no hardware.
- **MCP server tests** — each tool's output validated (scaffold compiles, doctor detects
  seeded misconfigurations, simulate emits correct state sequences).
- **Hardware smoke test** — one real end-to-end unlock per release against a bench reader
  (manual, pre-release gate).

## 7. Repository layout

```
wave-sdk/
  contract/        openapi.yaml, wave-protocol.json, conformance/*.json
  packages/
    swift/         WaveUnlock (SPM) + WaveUnlockButton + watchOS
    kotlin/        wave-unlock (AAR) + Compose button
    react-native/  @wave/unlock-react-native
    flutter/       wave_unlock
    web/           @wave/unlock-web (foreground-only)
    mcp/           @wave/mcp  ← primary channel
  gateway/         Supabase Edge Functions + migrations
                     (partner-auth, unlock-stream, unlock-mock; partners table)
  docs/            llms.txt, llms-full.txt, examples/<platform>/ (+ CLAUDE.md each)
  codegen/         generators: contract → per-language clients/types
```

## 8. Build order (feeds the implementation plan)

1. **Contract first** — `wave-protocol.json`, `openapi.yaml`, conformance vectors.
   Everything else generates from or is validated against this.
2. **Gateway** — Supabase Edge Functions extending `unlock-event`: `partner-auth`
   (key issuance + token mint), `unlock-stream` (per-tenant read), `unlock-mock`;
   `partners` table + tightened RLS.
3. **Swift core** — extract from the existing Wave Passport app; make conformance green.
4. **Kotlin core** — port; conformance green.
5. **MCP server** — the primary channel; wraps scaffold/doctor/simulate against 1–4.
6. **RN + Flutter bridges**, then **web tier**.
7. **Docs bundle + example repos + `llms.txt`**.

Cross-platform parity is enforced by the conformance vectors at every step, not by manual
review.
