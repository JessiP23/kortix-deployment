#!/usr/bin/env bash
# End-to-end smoke test for Azure Kortix deployment.
#
# Layers:
#   A) Preflight (no auth) — API health, Daytona API, deploy env on Container App
#   B) Session boot (needs PAT) — create session, wait for sandbox + runtimeReady
#
# Usage:
#   ./test-e2e-azure.sh                    # preflight only
#   KORTIX_PAT='kortix_pat_…' ./test-e2e-azure.sh
#   KORTIX_PROJECT_ID='ceed7663-…' KORTIX_PAT='…' ./test-e2e-azure.sh
#
# Create a PAT: Kortix UI → Account → API tokens (or project CLI token).
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
fail() { echo -e "${RED}✗${NC} $*"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEPLOY="$SCRIPT_DIR/deploy-azure.sh"

API_URL="$(grep '^API_URL=' "$DEPLOY" | head -1 | cut -d= -f2- | tr -d '"')"
PROJECT_ID="${KORTIX_PROJECT_ID:-ceed7663-84b4-4ca6-8d20-935bb9f39894}"
BOOT_TIMEOUT="${BOOT_TIMEOUT:-300}"
PAT="${KORTIX_PAT:-}"

command -v curl >/dev/null || fail "curl required"
command -v jq >/dev/null || fail "jq required"

echo "═══════════════════════════════════════════════════════════"
echo " Kortix Azure E2E — preflight"
echo " API: $API_URL"
echo "═══════════════════════════════════════════════════════════"
echo ""

# ── 1. Daytona (from deploy-azure.sh) ───────────────────────
if [ -x "$SCRIPT_DIR/test-daytona-config.sh" ]; then
  "$SCRIPT_DIR/test-daytona-config.sh" || fail "Daytona preflight failed"
else
  warn "test-daytona-config.sh not found — skip Daytona check"
fi
echo ""

# ── 2. API health ───────────────────────────────────────────
echo "🔗 GET $API_URL/v1/health"
HTTP="$(curl -sS -m 15 -o /tmp/kortix-health.json -w '%{http_code}' "$API_URL/v1/health" || echo 000)"
[ "$HTTP" = "200" ] || fail "API health HTTP $HTTP (expected 200)"
ok "API health HTTP 200"
if jq -e . >/dev/null 2>&1 </tmp/kortix-health.json; then
  jq -r 'keys[]' /tmp/kortix-health.json 2>/dev/null | head -5 | sed 's/^/   /' || true
fi
echo ""

# ── 3. Live Container App env (optional, needs az login) ──
if command -v az >/dev/null 2>&1; then
  echo "🔍 kortix-api env (Azure)"
  ENV_JSON="$(az containerapp show -g kortix-rg -n kortix-api \
    --query "properties.template.containers[0].env" -o json 2>/dev/null || echo '[]')"
  check_env() {
    local name="$1" expected="$2"
    local val
    val="$(echo "$ENV_JSON" | jq -r --arg n "$name" '.[] | select(.name==$n) | .value' 2>/dev/null | head -1)"
    if [ -z "$val" ] || [ "$val" = "null" ]; then
      warn "$name not set on container"
    elif [ -n "$expected" ] && [ "$val" != "$expected" ]; then
      warn "$name=$val (expected $expected)"
    else
      ok "$name=${val:-<set>}"
    fi
  }
  check_env KORTIX_URL "$API_URL"
  check_env KORTIX_GIT_PROXY "true"
  check_env KORTIX_DEFAULT_SANDBOX_DISK_GB "10"
  check_env KORTIX_DEFAULT_SANDBOX_MEMORY_GB "2"
  check_env KORTIX_WARM_POOL_MAX_TOTAL "0"
  check_env DAYTONA_SERVER_URL "https://app.daytona.io/api"
  echo ""
else
  warn "az CLI not available — skip live env check (install Azure CLI or verify env in portal)"
  echo ""
fi

# ── 4. DB default template row (optional, needs psql) ───────
if [ -x "$SCRIPT_DIR/fix-default-sandbox-disk.sh" ] && command -v psql >/dev/null 2>&1; then
  DATABASE_URL="$(grep '^DATABASE_URL=' "$DEPLOY" | head -1 | cut -d= -f2- | tr -d '"')"
  ROW="$(psql "$DATABASE_URL" -t -A -c \
    "SELECT memory_gb, disk_gb, provider_state FROM kortix.sandbox_templates
     WHERE project_id IS NULL AND slug='default' AND is_shared=TRUE LIMIT 1;" 2>/dev/null || true)"
  if [ -n "$ROW" ]; then
    MEM="$(echo "$ROW" | cut -d'|' -f1)"
    DISK="$(echo "$ROW" | cut -d'|' -f2)"
    STATE="$(echo "$ROW" | cut -d'|' -f3)"
    [ "$MEM" = "2" ] && [ "$DISK" = "10" ] && ok "DB default template: memory=${MEM}GiB disk=${DISK}GiB state=$STATE" \
      || warn "DB default template: memory=$MEM disk=$DISK state=$STATE (want 2/10)"
  fi
  echo ""
fi

# ── 5. Session boot (requires PAT) ─────────────────────────
if [ -z "$PAT" ]; then
  echo "───────────────────────────────────────────────────────────"
  echo " Preflight done. For full E2E (session + sandbox + agent):"
  echo ""
  echo "  1. Kortix UI → create an API token (account or project PAT)"
  echo "  2. Run:"
  echo "     KORTIX_PAT='<token>' KORTIX_PROJECT_ID='$PROJECT_ID' \\"
  echo "       $SCRIPT_DIR/test-e2e-azure.sh"
  echo ""
  echo " Manual UI checklist:"
  echo "  • Sandbox templates → Default → Ready"
  echo "  • One session (not many) → wait until running"
  echo "  • Send: \"Reply with exactly: pong\""
  echo "  • Expect agent reply in thread"
  echo "───────────────────────────────────────────────────────────"
  exit 0
fi

echo "═══════════════════════════════════════════════════════════"
echo " Kortix Azure E2E — session boot (project $PROJECT_ID)"
echo "═══════════════════════════════════════════════════════════"
echo ""

api() {
  curl -sS --max-time 120 -X "$1" \
    -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    ${3:+-d "$3"} \
    -w $'\n%{http_code}' \
    "$API_URL/v1$2"
}

body_of() { sed '$d' <<<"$1"; }
code_of() { tail -n1 <<<"$1"; }

echo "▸ POST /projects/$PROJECT_ID/sessions"
RESP="$(api POST "/projects/$PROJECT_ID/sessions" '{}')"
CODE="$(code_of "$RESP")"
BODY="$(body_of "$RESP")"
[ "$CODE" = "201" ] || [ "$CODE" = "200" ] || fail "create session HTTP $CODE: $BODY"
SESSION_ID="$(echo "$BODY" | jq -r '.session_id // .id // empty')"
[ -n "$SESSION_ID" ] || fail "no session_id in response: $BODY"
ok "session $SESSION_ID created (HTTP $CODE)"

SANDBOX_EXTERNAL=""
DEADLINE=$(( $(date +%s) + BOOT_TIMEOUT ))
echo "▸ Waiting for sandbox active (max ${BOOT_TIMEOUT}s)…"
while [ "$(date +%s)" -lt "$DEADLINE" ]; do
  SB="$(api GET "/projects/$PROJECT_ID/sessions/$SESSION_ID/sandbox")"
  SBCODE="$(code_of "$SB")"
  SBBODY="$(body_of "$SB")"
  if [ "$SBCODE" = "200" ]; then
    SANDBOX_EXTERNAL="$(echo "$SBBODY" | jq -r '.external_id // .sandbox_external_id // empty')"
    STATUS="$(echo "$SBBODY" | jq -r '.status // empty')"
    ok "sandbox active external_id=${SANDBOX_EXTERNAL:-?} status=${STATUS:-?}"
    break
  fi
  SESS="$(api GET "/projects/$PROJECT_ID/sessions/$SESSION_ID")"
  ST="$(body_of "$SESS" | jq -r '.status // "?"')"
  echo "   … session status=$ST sandbox HTTP $SBCODE"
  [ "$ST" = "failed" ] && fail "session failed: $(body_of "$SESS")"
  sleep 5
done
[ -n "$SANDBOX_EXTERNAL" ] || fail "sandbox not active within ${BOOT_TIMEOUT}s"

echo "▸ POST …/wake (if stopped)"
api POST "/projects/$PROJECT_ID/sessions/$SESSION_ID/wake" '{}' >/dev/null || true

echo "▸ Waiting for runtimeReady via preview /kortix/health (max 120s)…"
READY_DEADLINE=$(( $(date +%s) + 120 ))
RUNTIME_READY=false
while [ "$(date +%s)" -lt "$READY_DEADLINE" ]; do
  HEALTH="$(curl -sS -m 30 -H "Authorization: Bearer $PAT" \
    "$API_URL/v1/p/$SANDBOX_EXTERNAL/8000/kortix/health" 2>/dev/null || echo '{}')"
  if echo "$HEALTH" | jq -e '.runtimeReady == true' >/dev/null 2>&1; then
    RUNTIME_READY=true
    ok "runtimeReady=true"
    echo "$HEALTH" | jq '{runtimeReady, repoReady, opencodeReady, bootError}' 2>/dev/null || true
    break
  fi
  ERR="$(echo "$HEALTH" | jq -r '.bootError // .error // empty' 2>/dev/null)"
  [ -n "$ERR" ] && echo "   … boot: $ERR"
  sleep 3
done
$RUNTIME_READY || fail "runtime never became ready — check kortix-api logs for clone-credential / git proxy"

echo "▸ POST …/ensure-opencode"
EO="$(api POST "/projects/$PROJECT_ID/sessions/$SESSION_ID/ensure-opencode" '{}')"
EOCODE="$(code_of "$EO")"
[ "$EOCODE" = "200" ] || warn "ensure-opencode HTTP $EOCODE (may still work)"

if [ "${KEEP_SESSION:-0}" != "1" ]; then
  echo "▸ DELETE session (set KEEP_SESSION=1 to leave it running)"
  api DELETE "/projects/$PROJECT_ID/sessions/$SESSION_ID" >/dev/null || true
fi

echo ""
ok "E2E session boot passed"
echo " Next: send a chat message in the SAME session in Kortix UI (do not open New session per message)."
