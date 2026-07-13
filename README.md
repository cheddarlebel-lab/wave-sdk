# Wave Unlock SDK

Embed **Wave Passport BLE door unlock** into any app. MCP-first, contract-driven.

**Developer portal:** https://wave-developers.vercel.app — quickstart, live demo, `llms.txt`, OpenAPI.

## Layout

```
contract/            single source of truth: wave-protocol.json, openapi.yaml, conformance vectors
gateway/             end-to-end proof script (functions live in the Supabase project)
apps/developers/     the developer portal (static, on Vercel)
packages/
  mcp/               @wave/mcp — the primary integration channel (MCP server)
  swift/             WaveUnlock (SPM) + WaveUnlockButton
  kotlin/            wave-unlock core (+ Android BLE transport)
  react-native/      @wave/unlock-react-native (thin bridge)
  flutter/           wave_unlock (Dart core)
  web/               @wave/unlock-web (Web Bluetooth, foreground-only)
docs/                llms.txt, specs, plans
```

## The unlock, in one call

Every SDK hides the same 5-step pipeline behind one call: scan for the reader →
proximity gate on RSSI → write `0x01 + userNumber` (write-without-response) → await the
grant/deny verdict (direct-BLE or cloud) → surface a friendly result. All platforms are
kept behaviorally identical by the shared conformance vectors in `contract/conformance/`.

## Status

| Surface | State | Tests |
|---|---|---|
| Gateway (Supabase functions) | live | E2E verified |
| MCP server (`@wave/mcp`) | built | 19 + live + stdio |
| Developer portal | live | routes + demo verified |
| Swift core | built | 11 (`swift test`) |
| Kotlin core | built | 9 (`gradle test`) |
| Web SDK (`@wave/unlock-web`) | built | 5 (`vitest`) |
| Flutter core | built | 7 (`flutter test`) |
| React Native bridge | built | 3 (`vitest`) |

Native platform glue (RN/Flutter BLE modules) bridges the published Swift/Kotlin cores.

## For AI builders

Add the MCP server to your agent and say *"add Wave door unlock."* See the portal or
`docs/llms.txt`.
