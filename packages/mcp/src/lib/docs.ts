export function llmsText(): string {
  return `# Wave Unlock SDK — llms.txt

Wave Unlock lets your app open a Wave Passport door over Bluetooth LE.

## READ FIRST — the access model (governs whether a door ever opens)
The SDK SENDS the credential; the door controller DECIDES. A Wave credential resolves to a
\`cardID\`, and the controller grants ONLY if that cardID exists in the site's PROVIDER SOURCE
(the club's live membership system — MindBody/ABC/Glofox/TwinOaks/etc.) or its synced PROVIDER
CACHE, AND passes the membership rules (schedule, dues, check-in limits). Your app cannot mint
access for a non-member. "Has the app" != "gets in."
- Provider member id = what the user TYPES at enrollment (their id in the site's system). Used
  once, to find the person in the roster.
- cardID = the door-truth key validated on every unlock; the device resolves the typed id ->
  cardID at enrollment and binds the credential to it. A non-member enroll fails with \`not_found\`.
Two ways to make users door-eligible: (1) they are already members of the site's provider
(default — nothing to provision); (2) the site runs a Passport-hosted roster you provision users
into first (an operator/site setup step arranged with Passport, not a runtime SDK call).

## The flow (6 steps; the SDK owns 1-3 and rendering 6)
1. Scan for the reader (name prefix "SKBluTag", service 496B2C43-B05E-4A9A-9592-535173B7AB51).
2. Proximity gate on RSSI (default threshold -65, cloud-tunable per site).
3. Write credential: characteristic 995B637F-13F2-4335-96F5-5541ECFCE219,
   write WITHOUT response, payload = byte 0x01 followed by the userNumber as ASCII.
   Treat the write as immediate success; do NOT wait for a notify (it locks up). Disconnect after 1.5s.
4. Resolve (on-door acceptor): verifies the one-time token, hands the member's real cardID to the controller.
5. Decide (controller): validates the cardID against the site's provider source/cache + rules -> grant/deny.
   Steps 4-5 are outside your app — this is why a valid token can still be denied.
6. Await the cloud result (poll unlock-stream up to 5s) and show it: granted, or a friendly denial reason.

## Gateway API (exists today)
Base: https://app.wavepassport.com/api  — no API key header required; the branded gateway handles it.
- POST /partner-auth/token  { key: "wave_pub_*" | "wave_test_*" } -> { token, mode, expires_in }
- POST /unlock-stream  (Authorization: Bearer <token>)  { card_id } -> { status: granted|denied|pending, reason }
- POST /unlock-mock    (Authorization: Bearer <TEST token>)  { card_id, scenario } -> emits a synthetic event
- POST /partner-auth/register  (x-wave-admin-key)  { name, allowed_sites } -> keys (admin only)

## Keys
- wave_pub_*  publishable — safe in an app, exchange for a live session token.
- wave_test_* test — exchange for a test session token; only test tokens may drive /unlock-mock.
- wave_sk_*   secret — server-side only, NEVER embed in an app.

## Testing with no hardware
Call wave_simulate_unlock (or drive /unlock-mock + /unlock-stream with a test key) to prove
the whole grant/deny path end-to-end before you ever stand at a real door.

## MCP tools
wave_docs, wave_validate_config, wave_doctor, wave_scaffold, wave_register_app, wave_simulate_unlock.
`;
}
