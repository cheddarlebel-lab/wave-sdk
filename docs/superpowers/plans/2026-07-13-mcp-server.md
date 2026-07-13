# Wave Unlock SDK — MCP Server Implementation Plan (Phase 2)

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use checkbox syntax.

**Goal:** Ship `@wave/mcp` — the primary integration channel. A partner's coding agent adds this MCP server, and it can register the partner, scaffold an integration, validate config, diagnose a project, and run a full unlock simulation against the **live gateway** with no hardware.

**Architecture:** A TypeScript package built on `@modelcontextprotocol/sdk` (stdio transport). Pure logic (gateway client, config validation, project doctor, scaffolds) lives in `src/lib/` and is unit-tested with `vitest`; the MCP wiring in `src/index.ts` registers each tool. `wave_simulate_unlock` is integration-tested against the deployed gateway.

**Tech Stack:** TypeScript, `@modelcontextprotocol/sdk`, `zod`, `vitest`, tsc → `dist/`.

## Global Constraints

- Gateway base URL, anon key, and admin key come from env (`WAVE_GATEWAY_URL`, `WAVE_ANON_KEY`, `WAVE_ADMIN_KEY`) — never hardcoded.
- All gateway HTTP calls send `apikey: <anon>` (Supabase routing) + JSON body; session-token calls add `Authorization: Bearer <token>`.
- Key formats validated exactly as the gateway: `wave_pub_`+32hex, `wave_sk_`+48hex, `wave_test_`+32hex.
- Tools return MCP `content` text; structured data is JSON-stringified into a text block.
- The web scaffold targets the gateway HTTP API + Web Bluetooth (works today, no published native SDK). Native scaffolds are marked `preview` pending Phase 3.

## Tools shipped this phase

| Tool | Kind | Verified against |
|---|---|---|
| `wave_docs` | static | file |
| `wave_validate_config` | pure | unit |
| `wave_doctor` | pure (fs scan) | unit |
| `wave_scaffold` | template | unit (web runnable) |
| `wave_register_app` | live gateway | integration |
| `wave_simulate_unlock` | live gateway | integration |

## Tasks

### Task 1: Package scaffold + gateway client
- Create `packages/mcp/{package.json,tsconfig.json,vitest.config.ts}`.
- Create `src/lib/gateway.ts`: `registerPartner`, `getToken`, `emitMock`, `readStream`, `simulate` (compose token→mock→stream). Pure fetch wrappers taking a `GatewayConfig`.
- Unit-test URL/headers/body shaping with a stubbed `fetch`.

### Task 2: Validation + doctor
- `src/lib/validate.ts`: `validateConfig({key, sites})` → `{ok, errors[]}`.
- `src/lib/doctor.ts`: `doctorProject(dir)` → scans for iOS `NSBluetoothAlwaysUsageDescription` / background modes and Android `BLUETOOTH_SCAN/CONNECT`; returns findings.
- Unit tests with fixture dirs.

### Task 3: Scaffolds + docs
- `src/lib/scaffold.ts`: `scaffold(platform, style)` → `{files: {path, contents}[]}`. Web target fully runnable against the gateway.
- `src/lib/docs.ts`: `llmsText()` returns the flat SDK overview.
- Unit tests assert web scaffold references the gateway endpoints + validates.

### Task 4: MCP wiring + integration verify
- `src/index.ts`: register all six tools with zod schemas on an MCP `Server` over stdio.
- Integration test: run `simulate` against the live gateway with a freshly-registered test key; assert `granted`.
- Build (`tsc`), commit.

## Self-Review
- MCP-primary-channel spec §4 tools → all six present (register/validate/doctor/scaffold/docs/simulate). Snippet + changelog deferred (noted).
- `simulate_unlock` = the unattended-integration differentiator → Task 1 + Task 4 integration test.
