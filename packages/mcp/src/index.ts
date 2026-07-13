#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { registerPartner, simulate, type GatewayConfig } from "./lib/gateway.js";
import { validateConfig } from "./lib/validate.js";
import { doctorProject } from "./lib/doctor.js";
import { scaffold } from "./lib/scaffold.js";
import { llmsText } from "./lib/docs.js";

function gatewayConfig(): GatewayConfig {
  const baseUrl = process.env.WAVE_GATEWAY_URL ?? "";
  const anonKey = process.env.WAVE_ANON_KEY ?? "";
  return { baseUrl, anonKey, adminKey: process.env.WAVE_ADMIN_KEY };
}

function text(data: unknown) {
  const body = typeof data === "string" ? data : JSON.stringify(data, null, 2);
  return { content: [{ type: "text" as const, text: body }] };
}

function requireGateway(cfg: GatewayConfig): string | null {
  if (!cfg.baseUrl) return "WAVE_GATEWAY_URL env is not set";
  // WAVE_ANON_KEY is optional: the branded gateway (app.wavepassport.com/api)
  // injects the key server-side. Only needed if pointing directly at Supabase.
  return null;
}

const server = new McpServer({ name: "wave-mcp", version: "0.1.0" });

server.tool(
  "wave_docs",
  "Return the Wave Unlock SDK overview (llms.txt) — the knowledge source for integrating BLE door unlock.",
  {},
  async () => text(llmsText()),
);

server.tool(
  "wave_validate_config",
  "Validate a Wave config (API key format + sites) before you build.",
  { key: z.string().optional(), sites: z.array(z.string()).optional() },
  async (args) => text(validateConfig(args)),
);

server.tool(
  "wave_doctor",
  "Scan an app project for the common BLE integration mistakes (missing iOS Info.plist keys / Android permissions) that cause silent unlock failures.",
  { project_path: z.string() },
  async ({ project_path }) => text(doctorProject(project_path)),
);

server.tool(
  "wave_scaffold",
  "Generate a starter integration for a platform. 'web' is runnable today against the gateway; native platforms are Phase 3 previews.",
  {
    platform: z.enum(["web", "ios", "android", "react-native", "flutter"]),
    style: z.enum(["headless", "drop-in"]).default("drop-in"),
  },
  async ({ platform, style }) => text(scaffold(platform, style)),
);

server.tool(
  "wave_register_app",
  "Provision a new partner in the Wave gateway (admin only). Returns publishable + test keys ONCE. Requires WAVE_ADMIN_KEY env.",
  { name: z.string(), allowed_sites: z.array(z.string()) },
  async ({ name, allowed_sites }) => {
    const cfg = gatewayConfig();
    const missing = requireGateway(cfg);
    if (missing) return text({ error: missing });
    if (!cfg.adminKey) return text({ error: "WAVE_ADMIN_KEY env is not set" });
    try {
      return text(await registerPartner(cfg, name, allowed_sites));
    } catch (e) {
      return text({ error: (e as Error).message });
    }
  },
);

server.tool(
  "wave_simulate_unlock",
  "Prove the full unlock flow end-to-end with NO hardware: exchanges a test key for a token, emits a scenario via the mock, and reads the result back. Scenarios: granted, member_not_found, outside_hours, membership_expired, outstanding_balance.",
  {
    test_key: z.string().describe("wave_test_* key"),
    card_id: z.string().default("10001"),
    scenario: z.string().default("granted"),
  },
  async ({ test_key, card_id, scenario }) => {
    const cfg = gatewayConfig();
    const missing = requireGateway(cfg);
    if (missing) return text({ error: missing });
    try {
      return text(await simulate(cfg, test_key, card_id, scenario));
    } catch (e) {
      return text({ error: (e as Error).message });
    }
  },
);

const transport = new StdioServerTransport();
await server.connect(transport);
