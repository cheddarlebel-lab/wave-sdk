# Wave Unlock — agent integration guide

You are integrating Wave Passport BLE door unlock into an app. Everything you need:

## Facts
- **Docs (flat, for you):** https://wave-developers.vercel.app/llms-full.txt
- **Gateway base:** `https://zuijamqvgxvajvhrdnlx.supabase.co/functions/v1` (every call also sends header `apikey: <supabase anon key>`)
- **Public anon key:** `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp1aWphbXF2Z3h2YWp2aHJkbmx4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI3MzI2NTUsImV4cCI6MjA4ODMwODY1NX0.KswD9UTeooxK9J3J-uJIZCCI_uLnRcJK9z2gLY5qaxg`
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
Add `@wave/mcp` to your MCP config with `WAVE_GATEWAY_URL` + `WAVE_ANON_KEY`, then use
`wave_docs`, `wave_scaffold`, `wave_doctor`, `wave_simulate_unlock`. The server does the
integration and self-tests it.
