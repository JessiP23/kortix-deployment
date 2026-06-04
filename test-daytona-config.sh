#!/usr/bin/env bash
# Verify Daytona config in deploy-azure.sh returns JSON API, not Framer HTML.
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEPLOY="$SCRIPT_DIR/deploy-azure.sh"

DAYTONA_API_KEY="$(grep '^DAYTONA_API_KEY=' "$DEPLOY" | head -1 | cut -d= -f2- | tr -d '"')"
DAYTONA_SERVER_URL="$(grep '^DAYTONA_SERVER_URL=' "$DEPLOY" | head -1 | cut -d= -f2- | tr -d '"')"
DAYTONA_TARGET="$(grep '^DAYTONA_TARGET=' "$DEPLOY" | head -1 | cut -d= -f2- | tr -d '"')"

echo "📋 From deploy-azure.sh:"
echo "   DAYTONA_SERVER_URL=$DAYTONA_SERVER_URL"
echo "   DAYTONA_TARGET=$DAYTONA_TARGET"
echo "   DAYTONA_API_KEY=${DAYTONA_API_KEY:0:12}..."
echo ""

if [ -z "$DAYTONA_API_KEY" ] || [ -z "$DAYTONA_SERVER_URL" ]; then
  echo -e "${RED}✗${NC} Missing DAYTONA_API_KEY or DAYTONA_SERVER_URL in deploy-azure.sh"
  exit 1
fi

BASE="${DAYTONA_SERVER_URL%/}"
echo "🔗 GET $BASE/snapshots?limit=1"
BODY="$(curl -sS -w "\n%{http_code}" -H "Authorization: Bearer $DAYTONA_API_KEY" -H "Accept: application/json" "$BASE/snapshots?limit=1")"
HTTP="$(echo "$BODY" | tail -n1)"
RESP="$(echo "$BODY" | sed '$d')"

if echo "$RESP" | head -c 200 | grep -qi '<html'; then
  echo -e "${RED}✗${NC} Daytona returned HTML (wrong URL — this causes the Framer snapshot error)"
  echo "$RESP" | head -c 300
  echo ""
  echo "Fix: use DAYTONA_SERVER_URL=https://app.daytona.io/api and DAYTONA_TARGET=us or eu"
  exit 1
fi

if [ "$HTTP" = "200" ] || [ "$HTTP" = "401" ] || [ "$HTTP" = "403" ]; then
  if [ "$HTTP" = "200" ]; then
    echo -e "${GREEN}✓${NC} Daytona API OK (HTTP 200, JSON response)"
  else
    echo -e "${YELLOW}⚠${NC} HTTP $HTTP — check API key in Daytona dashboard (app.daytona.io)"
  fi
else
  echo -e "${RED}✗${NC} Unexpected HTTP $HTTP"
  echo "$RESP" | head -c 400
  exit 1
fi

echo ""
echo "If this passes but Kortix UI still shows Framer HTML:"
echo "  1. Redeploy kortix-api: ./deploy-azure.sh <version>"
echo "  2. Confirm live env: az containerapp show -g kortix-rg -n kortix-api --query properties.template.containers[0].env"
echo "  3. Try DAYTONA_TARGET=eu if your Daytona org is EU (Supabase is eu-central-2)"
