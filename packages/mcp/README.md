# @wave/mcp — Wave Unlock MCP Server

The **primary integration channel** for Wave Passport BLE door unlock. Add this MCP
server to your AI coding agent (Claude Code, Cursor) and tell it *"add Wave door unlock
to my app"* — it scaffolds the integration, validates your config, diagnoses your
project, and proves the whole grant/deny flow end-to-end **with no hardware**.

## Install

Add to your MCP client config (Claude Code `~/.claude.json` / Cursor `mcp.json`):

```json
{
  "mcpServers": {
    "wave": {
      "command": "npx",
      "args": ["-y", "@wave/mcp"],
      "env": {
        "WAVE_GATEWAY_URL": "https://app.wavepassport.com/api",
        "WAVE_ADMIN_KEY": "<only if you provision partners>"
      }
    }
  }
}
```

## Tools

| Tool | What it does |
|---|---|
| `wave_docs` | The SDK overview (llms.txt) — the agent's knowledge source. |
| `wave_validate_config` | Validate an API key + sites before you build. |
| `wave_doctor` | Scan a project for missing iOS Bluetooth usage strings / Android BLE permissions. |
| `wave_scaffold` | Generate a starter (`web` runs today; native = Phase 3 preview). |
| `wave_register_app` | Provision a partner, get publishable + test keys (admin only). |
| `wave_simulate_unlock` | Prove granted/denied end-to-end via the mock — **no reader needed**. |

## The unattended-integration loop

1. `wave_register_app` → publishable + test keys.
2. `wave_scaffold web` → drop-in unlock page wired to the gateway.
3. `wave_doctor` → catch missing permissions before build.
4. `wave_simulate_unlock` (test key) → confirm the full flow returns `granted`/`denied`.

No physical door, no back-and-forth. That's the point.

## Develop

```bash
npm install
npm test        # 19 unit tests
npm run build   # tsc -> dist/
```
