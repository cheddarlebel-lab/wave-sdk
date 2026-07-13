export type ScaffoldFile = { path: string; contents: string };
export type ScaffoldResult = { platform: string; style: string; preview: boolean; files: ScaffoldFile[]; notes: string[] };

const WEB_HTML = `<!doctype html>
<html>
<head><meta charset="utf-8"><title>Wave Unlock Demo</title></head>
<body>
  <button id="unlock">Unlock door</button>
  <pre id="log"></pre>
  <script type="module" src="./wave-unlock.js"></script>
</body>
</html>
`;

const WEB_JS = `// Wave Unlock — web (Web Bluetooth + gateway). Foreground-only.
// Fill these in from wave_register_app / your Wave dashboard:
const WAVE = {
  gatewayUrl: "https://app.wavepassport.com/api",   // branded gateway, no key needed
  publishableKey: "wave_pub_xxxxxxxx",              // from wave_register_app / the Wave team
  serviceUuid: "496b2c43-b05e-4a9a-9592-535173b7ab51",
  writeCharacteristic: "995b637f-13f2-4335-96f5-5541ecfce219",
  userNumber: "10001",
};

const log = (m) => (document.getElementById("log").textContent += m + "\\n");

async function token() {
  const r = await fetch(WAVE.gatewayUrl + "/partner-auth/token", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ key: WAVE.publishableKey }),
  });
  return (await r.json()).token;
}

async function unlock() {
  log("scanning…");
  const device = await navigator.bluetooth.requestDevice({
    filters: [{ namePrefix: "SKBluTag" }],
    optionalServices: [WAVE.serviceUuid],
  });
  const server = await device.gatt.connect();
  const svc = await server.getPrimaryService(WAVE.serviceUuid);
  const ch = await svc.getCharacteristic(WAVE.writeCharacteristic);
  const payload = new Uint8Array([0x01, ...new TextEncoder().encode(WAVE.userNumber)]);
  log("writing…");
  await ch.writeValueWithoutResponse(payload);
  setTimeout(() => server.disconnect(), 1500);

  log("awaiting confirmation…");
  const t = await token();
  const deadline = Date.now() + 5000;
  while (Date.now() < deadline) {
    const r = await fetch(WAVE.gatewayUrl + "/unlock-stream", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: "Bearer " + t },
      body: JSON.stringify({ card_id: WAVE.userNumber }),
    });
    const { status, reason } = await r.json();
    if (status !== "pending") return log(status.toUpperCase() + (reason ? " — " + reason : ""));
    await new Promise((res) => setTimeout(res, 500));
  }
  log("timed out — no confirmation");
}

document.getElementById("unlock").addEventListener("click", () => unlock().catch((e) => log("error: " + e.message)));
`;

export function scaffold(platform: string, style: string): ScaffoldResult {
  const p = platform.toLowerCase();
  if (p === "web") {
    return {
      platform: "web",
      style,
      preview: false,
      files: [
        { path: "index.html", contents: WEB_HTML },
        { path: "wave-unlock.js", contents: WEB_JS },
      ],
      notes: [
        "Runnable today against the live gateway + Web Bluetooth (Chrome/Edge, foreground-only).",
        "Replace publishableKey / userNumber (the gateway URL defaults to production).",
        "Serve over https (Web Bluetooth requires a secure context).",
      ],
    };
  }
  if (p === "ios" || p === "android" || p === "react-native" || p === "flutter") {
    return {
      platform: p,
      style,
      preview: true,
      files: [],
      notes: [
        `Native ${p} scaffold is a Phase 3 preview — the native package is not published yet.`,
        "Use the 'web' scaffold to validate the full unlock flow against the gateway today,",
        "or call wave_simulate_unlock to prove your integration end-to-end with no hardware.",
      ],
    };
  }
  return { platform, style, preview: true, files: [], notes: [`Unknown platform '${platform}'. Try: web, ios, android, react-native, flutter.`] };
}
