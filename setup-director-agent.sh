#!/usr/bin/env bash
set -e

# ============================================================
# Director Agent Setup Script for Kortix
# This script helps set up the Director agent in Kortix
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DIRECTOR_AGENT_DIR="$SCRIPT_DIR/director-agent"

echo "🚀 Setting up Director agent for Kortix..."
echo ""

# Check if director-agent directory exists
if [ ! -d "$DIRECTOR_AGENT_DIR" ]; then
  echo "❌ Director agent directory not found: $DIRECTOR_AGENT_DIR"
  exit 1
fi

echo "✅ Director agent files found at: $DIRECTOR_AGENT_DIR"
echo ""
echo "📁 Director agent structure:"
find "$DIRECTOR_AGENT_DIR" -type f -name "*.md" -o -name "*.jsonc" | sort
echo ""

echo "📋 Next steps to complete the setup:"
echo ""
echo "1. Create a Kortix project for Director:"
echo "   - Go to Kortix frontend: https://kortix-frontend.blueplant-341a6571.eastus.azurecontainerapps.io"
echo "   - Create a new project"
echo "   - Note the project ID"
echo ""
echo "2. Copy Director agent files to the Kortix project:"
echo "   - The agent files are in: $DIRECTOR_AGENT_DIR"
echo "   - Copy .kortix/ directory to your Kortix project"
echo "   - Or use the Kortix CLI to scaffold the agent"
echo ""
echo "3. Configure the agent in Kortix:"
echo "   - The agent definition is at: .kortix/opencode/agents/director.md"
echo "   - The skills are at: .kortix/opencode/skills/director-production/"
echo "   - The config is at: .kortix/opencode/opencode.jsonc"
echo ""
echo "4. Test the agent:"
echo "   - Create a session in the Kortix project"
echo "   - Send a test message"
echo "   - Verify the agent responds correctly"
echo ""
echo "5. Configure authentication:"
echo "   - Set KORTIX_API_KEY in wmstudio .env"
echo "   - Or use Supabase JWT authentication"
echo "   - See KORTIX_DIRECTOR_INTEGRATION.md for details"
echo ""
echo "✅ Setup instructions complete!"
echo ""
echo "📖 For more information, see: $SCRIPT_DIR/KORTIX_DIRECTOR_INTEGRATION.md"
