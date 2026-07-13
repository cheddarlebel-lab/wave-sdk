#!/usr/bin/env bash
# End-to-end proof of the Wave Unlock gateway: register -> token -> mock -> stream,
# plus a tenant-isolation negative test. Runs against the branded, keyless gateway.
#
# Required env:
#   ADMIN = WAVE_ADMIN_KEY (from the function secrets; needed only for /register)
# Optional:
#   BASE  = gateway base (defaults to the production FQDN)
set -euo pipefail
BASE="${BASE:-https://app.wavepassport.com/api}"
: "${ADMIN:?set ADMIN=<WAVE_ADMIN_KEY>}"

H=(-H "Content-Type: application/json")

jval() { grep -o "\"$1\":\"[^\"]*\"" | head -1 | cut -d'"' -f4; }

echo "== register partner A (site CBSM-TEST-1) =="
REG_A=$(curl -s "${H[@]}" -H "x-wave-admin-key: $ADMIN" \
  -d '{"name":"E2E Test Co A","allowed_sites":["CBSM-TEST-1"]}' "$BASE/partner-auth/register")
echo "$REG_A"
TEST_KEY_A=$(echo "$REG_A" | jval test_key)
[ -n "$TEST_KEY_A" ] || { echo "FAIL: no test key for A"; exit 1; }

echo "== exchange A test key for token (expect mode=test) =="
TOK_A=$(curl -s "${H[@]}" -d "{\"key\":\"$TEST_KEY_A\"}" "$BASE/partner-auth/token")
echo "$TOK_A"
SESSION_A=$(echo "$TOK_A" | jval token)
echo "$TOK_A" | grep -q '"mode":"test"' || { echo "FAIL: expected test mode"; exit 1; }

echo "== stream A before mock: expect pending =="
S0=$(curl -s "${H[@]}" -H "Authorization: Bearer $SESSION_A" -d '{"card_id":"10001"}' "$BASE/unlock-stream")
echo "$S0"
echo "$S0" | grep -q '"status":"pending"' || { echo "FAIL: expected pending"; exit 1; }

echo "== emit granted mock for A =="
curl -s "${H[@]}" -H "Authorization: Bearer $SESSION_A" \
  -d '{"card_id":"10001","scenario":"granted"}' "$BASE/unlock-mock"; echo

echo "== stream A after mock: expect granted =="
S1=$(curl -s "${H[@]}" -H "Authorization: Bearer $SESSION_A" -d '{"card_id":"10001"}' "$BASE/unlock-stream")
echo "$S1"
echo "$S1" | grep -q '"status":"granted"' || { echo "FAIL: expected granted"; exit 1; }

echo "== TENANT ISOLATION: register partner B (site CBSM-OTHER) =="
REG_B=$(curl -s "${H[@]}" -H "x-wave-admin-key: $ADMIN" \
  -d '{"name":"E2E Test Co B","allowed_sites":["CBSM-OTHER"]}' "$BASE/partner-auth/register")
TEST_KEY_B=$(echo "$REG_B" | jval test_key)
TOK_B=$(curl -s "${H[@]}" -d "{\"key\":\"$TEST_KEY_B\"}" "$BASE/partner-auth/token")
SESSION_B=$(echo "$TOK_B" | jval token)

echo "== stream B for card 10001: must NOT see A's event (expect pending) =="
SB=$(curl -s "${H[@]}" -H "Authorization: Bearer $SESSION_B" -d '{"card_id":"10001"}' "$BASE/unlock-stream")
echo "$SB"
echo "$SB" | grep -q '"status":"pending"' || { echo "FAIL: tenant isolation breach"; exit 1; }

echo "== mock rejects a live-mode token (register->pub key->token->mock => 403) =="
PUB_A=$(echo "$REG_A" | jval publishable_key)
TOK_LIVE=$(curl -s "${H[@]}" -d "{\"key\":\"$PUB_A\"}" "$BASE/partner-auth/token")
SESSION_LIVE=$(echo "$TOK_LIVE" | jval token)
MOCK_LIVE=$(curl -s "${H[@]}" -H "Authorization: Bearer $SESSION_LIVE" \
  -d '{"card_id":"10001","scenario":"granted"}' "$BASE/unlock-mock")
echo "$MOCK_LIVE"
echo "$MOCK_LIVE" | grep -q "test-mode token" || { echo "FAIL: mock accepted a live token"; exit 1; }

echo "E2E PASS"
