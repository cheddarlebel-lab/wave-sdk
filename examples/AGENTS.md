# Wave Unlock — agent integration guide

You are integrating Wave Passport BLE door unlock into an app. Everything you need:

## Facts
- **Docs (flat, for you):** https://app.wavepassport.com/developers/llms-full.txt
- **Gateway base:** `https://app.wavepassport.com/api` (no API key header needed — the gateway handles it)
- **Public demo test key:** `wave_test_9097529120bb93a92d058d65007fb555` (test-mode → drives the mock only; cannot open a real door)

## The fastest path
1. Prove the flow with **no hardware**: exchange the demo test key for a token, POST a scenario to `/unlock-mock`, read `/unlock-stream`. See `web/` for a runnable page.
2. Pick a platform folder for the real integration snippet (`swift/`, `kotlin/`, `react-native/`, `flutter/`, `web/`).
3. Get real keys: run the MCP tool `wave_register_app`, or ask the Wave team.
4. Before building, run `wave_doctor` (MCP) — it checks the BLE permissions below.

## BLE permissions you MUST add
- **iOS** `Info.plist`: `NSBluetoothAlwaysUsageDescription`; `UIBackgroundModes` → `bluetooth-central`.
- **Android** `AndroidManifest.xml`: `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`.

## MCP server (preferred)
Add `@wave/mcp` to your MCP config with `WAVE_GATEWAY_URL` (the branded `/api` gateway), then use
`wave_docs`, `wave_scaffold`, `wave_doctor`, `wave_simulate_unlock`. The server does the
integration and self-tests it.
