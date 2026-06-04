# Kortix Director Integration Guide

This guide explains how Director uses Kortix as the full agent system, replacing the local LangChain runtime with Kortix's OpenCode runtime, skills, and MCP integration.

## Architecture

```
WM Studio Web App
    ↓ (Supabase auth)
Kortix API (projects/sessions/sandboxes)
    ↓ (OpenCode runtime)
Kortix Agents (markdown definitions)
    ↓ (skill loading)
Kortix Skills (reusable workflows)
    ↓ (MCP server integration via Kortix)
External MCP Servers (Composio, others)
    ↓ (LLM calls)
OpenRouter Models
```

## Key Benefits

- **Kortix handles MCP natively** - No need for Director to manage MCP servers directly
- **Kortix handles Composio natively** - Integration already built into Kortix
- **Kortix handles memory** - Built-in memory system replaces Director's local memory
- **Kortix handles skills** - Reusable skill workflows replace Director's skills
- **Kortix handles tools** - Tool calling managed by Kortix's agent system
- **Sandbox isolation** - Each session runs in an isolated Daytona sandbox

## Deployment

### 1. Kortix Deployment

Kortix is deployed to Azure Container Apps with the following configuration:

```bash
cd /Users/jessipavia/wm/kortix-deployment
./deploy-azure.sh <version>
```

Key environment variables:
- `OPENCODE_ENABLED=true` - Enables OpenCode runtime
- `LLM_GATEWAY_ENABLED=true` - Enables LLM gateway
- `COMPOSIO_API_KEY=<key>` - Composio integration
- `OPENROUTER_API_KEY=<key>` - OpenRouter for LLM calls
- `DAYTONA_API_KEY=<key>` - Daytona for sandboxes

### 2. Director Agent Definition

The Director agent is defined in Kortix format at:
```
/Users/jessipavia/wm/kortix-deployment/director-agent/.kortix/opencode/agents/director.md
```

This defines Director as a creative production assistant with access to production skills.

### 3. Director Skills

Director skills are defined in Kortix format at:
```
/Users/jessipavia/wm/kortix-deployment/director-agent/.kortix/opencode/skills/director-production/
```

Skills:
- `briefing/` - Production brief creation and management
- `generation/` - Creative asset generation using MCP tools
- `editing/` - Timeline editing and post-production
- `review/` - Quality review and feedback

## MCP Integration

Kortix handles MCP servers natively. Director does not need to manage MCP servers directly.

### Adding MCP Servers to Kortix

MCP servers can be configured in Kortix through:
1. **Kortix UI** - Add MCP servers via the Kortix dashboard
2. **Kortix API** - Use the MCP server configuration API
3. **Configuration files** - Add MCP servers to project configuration

### Composio Integration

Composio is already integrated into Kortix. The `COMPOSIO_API_KEY` environment variable enables this integration.

To use Composio tools:
1. Configure Composio app integrations in the Composio dashboard
2. Kortix agents can automatically use Composio tools
3. No additional configuration needed in Director

## Director Runtime Integration

The Director runtime in `wmstudio/src/lib/production-agent/runtime/kortix-runtime.ts` uses Kortix's projects/sessions API:

1. **Get or create project** - One project per user
2. **Create session** - One session per Director run
3. **Send message** - User prompt sent to Kortix session
4. **Stream events** - SSE stream of session events
5. **Map events** - Kortix events mapped to Director events

### Environment Variables

Director needs these environment variables:
```bash
KORTIX_API_URL=https://kortix-api.blueplant-341a6571.eastus.azurecontainerapps.io/v1
KORTIX_API_KEY=kortix-api-secret-key-change-in-production
```

### Authentication Setup

Kortix uses Supabase for authentication. For Director integration, the authentication is already configured:

**Current Implementation:**
The Director runtime uses a fallback authentication strategy:
1. First tries `KORTIX_API_KEY` if set and not the placeholder
2. Falls back to `SUPABASE_SERVICE_ROLE_SECRET` for service-level access
3. This allows Director to authenticate to Kortix using the same Supabase instance

**No additional setup needed:**
- The `SUPABASE_SERVICE_ROLE_SECRET` is already in your wmstudio `.env`
- Director will use this to authenticate to Kortix automatically
- Kortix validates the Supabase JWT token
- Director can then create projects and sessions

**If you want to use user-level authentication:**
1. Create a user account in Kortix frontend
2. The user's Supabase JWT token will be used
3. This is handled automatically in the API route context

## Testing

### Test Kortix Deployment

```bash
curl https://kortix-api.blueplant-341a6571.eastus.azurecontainerapps.io/v1/health
```

### Test Director Integration

1. **Set up authentication:**
   - Set `KORTIX_API_KEY` in wmstudio `.env` file
   - Or ensure `SUPABASE_SERVICE_ROLE_SECRET` is set
   - The auth will fall back to Supabase service role key if KORTIX_API_KEY is placeholder

2. **Start wmstudio:**
```bash
cd /Users/jessipavia/wm/wmstudio
pnpm dev
```

3. **Test the integration:**
   - Go to `/dashboard/director`
   - Create a new chat
   - Send a message
   - Check logs for Kortix integration
   - Verify the response is streaming correctly

### Director Agent Setup

The Director agent definition is now in the wmstudio repository:
```
/Users/jessipavia/wm/wmstudio/.kortix/opencode/agents/director.md
```

This directory contains:
- `.kortix/opencode/agents/director.md` - Director agent definition
- `.kortix/opencode/skills/director-production/` - Director skills
- `.kortix/opencode/opencode.jsonc` - Kortix configuration

**To use this agent in Kortix:**

1. **Commit the agent files to wmstudio:**
   ```bash
   cd /Users/jessipavia/wm/wmstudio
   git add .kortix/
   git commit -m "Add Director agent for Kortix integration"
   git push
   ```

2. **Create a Kortix project:**
   - Go to Kortix frontend: https://kortix-frontend.blueplant-341a6571.eastus.azurecontainerapps.io
   - Create a new project
   - Connect it to the wmstudio git repository
   - Kortix will clone the repo and load the agent definition from `.kortix/opencode/`

3. **Configure the project:**
   - Set the primary agent to `director`
   - Configure skills to use `director-production/*`
   - Configure MCP servers if needed
   - Configure Composio integrations if needed

4. **Test the agent:**
   - Create a session in the Kortix project
   - Send a test message
   - Verify the agent responds correctly

## Migration

### From Local LangChain to Kortix

**What changes:**
- LangChain runtime → Kortix OpenCode runtime
- Local memory → Kortix memory system
- Local skills → Kortix skills
- Local MCP integration → Kortix MCP integration
- Local tool calling → Kortix tool calling

**What stays the same:**
- Director UI remains unchanged
- Director event model remains unchanged
- Director database schema remains unchanged
- User experience remains unchanged

### Data Migration

Director memories and skills can be migrated to Kortix format:
1. Export Director memories
2. Convert to Kortix memory format
3. Import into Kortix project
4. Export Director skills
5. Convert to Kortix skill format
6. Import into Kortix project

## Troubleshooting

### Kortix API Errors

- **404 on /v1/projects/:projectId/sessions** - Check OPENCODE_ENABLED is set
- **503 LLM gateway disabled** - Check LLM_GATEWAY_ENABLED is set
- **Authentication errors** - Check KORTIX_API_KEY is correct

### Session Errors

- **Session not created** - Check project exists and is accessible
- **Session not streaming** - Check SSE endpoint is accessible
- **Session failed** - Check Kortix logs for errors

### MCP Integration

- **MCP servers not accessible** - Check MCP server configuration in Kortix
- **Composio tools not working** - Check COMPOSIO_API_KEY is valid
- **Tool calling errors** - Check tool permissions in Kortix

## Next Steps

1. **Configure MCP servers** - Add required MCP servers to Kortix
2. **Configure Composio apps** - Set up Composio integrations
3. **Test end-to-end** - Verify full Director workflow with Kortix
4. **Migrate data** - Move Director memories and skills to Kortix
5. **Monitor performance** - Track session latency and costs
