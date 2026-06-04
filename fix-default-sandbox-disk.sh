#!/usr/bin/env bash
# Fix platform default template for Daytona standard tier limits:
# - disk_gb=10 (per-sandbox max; migration 95 seeded 20)
# - memory_gb=2 (org-wide RAM cap is 10 GiB; Kortix default 4 + warm pool exceeds it)
# Env vars alone do not override non-null columns in sandbox_templates.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEPLOY="$SCRIPT_DIR/deploy-azure.sh"

DATABASE_URL="$(grep '^DATABASE_URL=' "$DEPLOY" | head -1 | cut -d= -f2- | tr -d '"')"

if [ -z "$DATABASE_URL" ]; then
  echo "✗ DATABASE_URL not found in deploy-azure.sh"
  exit 1
fi

echo "Updating kortix.sandbox_templates (shared default) → disk_gb=10, memory_gb=2..."
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<'SQL'
UPDATE kortix.sandbox_templates
SET
  disk_gb = 10,
  memory_gb = 2,
  provider_state = 'missing',
  content_hash = NULL,
  provider_snapshot_name = NULL,
  last_error = NULL,
  updated_at = NOW()
WHERE project_id IS NULL
  AND slug = 'default'
  AND is_shared = TRUE;

SELECT slug, cpu, memory_gb, disk_gb, provider_state
FROM kortix.sandbox_templates
WHERE project_id IS NULL AND slug = 'default' AND is_shared = TRUE;
SQL

echo ""
echo "✓ Done. In Kortix UI → Sandbox templates → Rebuild Default (memory change = new snapshot hash)."
echo "  Set KORTIX_WARM_POOL_MAX_TOTAL=0 on kortix-api until Daytona org RAM limit is raised."
echo "  Delete stray sandboxes at https://app.daytona.io/dashboard if boots still fail."
