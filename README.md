# Kortix Deployment for Azure Container Apps

This repository contains the deployment configuration for Kortix/Suna on Azure Container Apps using Docker Compose.

## What to Deploy

- **suna/** - The Kortix source code (cloned from GitHub). This is what you build and deploy.
- **kortix-deployment/** - Deployment configuration (docker-compose.yml, scripts, .env). This is your deployment setup.

**For Azure deployment:** Use `deploy-azure.sh` which builds from the `suna/` directory and deploys to Azure Container Apps.

## Quick Start

### Prerequisites

- Docker and Docker Compose installed
- Supabase project (or local PostgreSQL)
- OpenRouter API key (or Groq API key for free tier)
- Daytona API key (for sandbox execution)
- (Optional) Composio API key for tool integrations

### Setup

1. **Clone Kortix repository** (if not already done):
   ```bash
   cd /Users/jessipavia/wm
   git clone https://github.com/kortix-ai/suna.git
   ```

2. **Configure environment variables**:
   ```bash
   cd kortix-deployment
   cp .env.example .env
   # Edit .env with your configuration
   ```

3. **Deploy**:
   ```bash
   ./deploy-azure.sh 0.9.5
   ```

## Configuration

### Required Environment Variables

Edit `.env` and configure:

```bash
# Supabase (Required)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
DATABASE_URL=postgresql://postgres:password@db.your-project.supabase.co:5432/postgres

# LLM Provider (Required)
OPENROUTER_API_KEY=your-openrouter-api-key

# Sandbox (Required)
DAYTONA_API_KEY=your-daytona-api-key

# Security (Required)
JWT_SECRET=generate-a-long-random-string
```

### Optional Environment Variables

```bash
# Groq (Free tier alternative)
GROQ_API_KEY=your-groq-api-key
DIRECTOR_MODEL_PROVIDER=groq  # Set to 'groq' to use Groq instead of OpenRouter

# Composio Integration
COMPOSIO_API_KEY=your-composio-api-key
COMPOSIO_ENV=production

# Features
BILLING_ENABLED=false
```

## Services

The Azure deployment includes:

- **kortix-api**: Kortix backend API
- **kortix-frontend**: Kortix web frontend
- **Azure Cache for Redis**: Redis for caching and session management

## Access Points

After Azure deployment:

- **Frontend**: https://kortix-frontend.azurewebsites.net
- **API**: https://kortix-api.azurewebsites.net
- **API Health**: https://kortix-api.azurewebsites.net/v1/health

## Azure Container Apps Deployment

Deploy to Azure Container Apps using the provided script (similar to wmstudio approach):

```bash
cd /Users/jessipavia/wm/kortix-deployment
./deploy-azure.sh 0.9.5
```

**Prerequisites:**
- Azure CLI installed and logged in (`az login`)
- .env file configured with your API keys

The script will:
1. Build Docker images from the suna source code
2. Push images to Azure Container Registry (ACR)
3. Create Azure Container Apps environment
4. Deploy API and Frontend to Azure Container Apps
5. Set up Azure Cache for Redis

**Required Azure resources** (auto-created by script):
- Resource Group: `kortix-rg`
- Azure Container Registry: `kortixacr`
- Container Apps Environment: `kortix-env`
- Azure Cache for Redis: `kortix-redis`

**Customize Azure settings** in `deploy-azure.sh`:
```bash
RESOURCE_GROUP="kortix-rg"
LOCATION="eastus"
ACR_NAME="kortixacr"
ENVIRONMENT_NAME="kortix-env"
```

## Troubleshooting

### Services won't start

Check Docker is running:
```bash
docker info
```

Check environment variables are set:
```bash
cat .env
```

View logs:
```bash
./deploy-kortix.sh logs
```

### Database connection issues

If using Supabase cloud, ensure:
- SUPABASE_URL is correct
- SUPABASE_ANON_KEY is valid
- DATABASE_URL matches your Supabase connection string

If using local PostgreSQL:
- Ensure postgres service is healthy
- Check DATABASE_URL matches postgres container

### LLM API errors

- Verify OPENROUTER_API_KEY is valid
- Check API key has credits/usage available
- Try Groq as a free alternative

## Next Steps

After successful deployment:

1. **Test the API**: `curl http://localhost:8008/v1/health`
2. **Access the frontend**: Open http://localhost:3000 in your browser
3. **Configure agents**: Create agents in Kortix's agent system
4. **Integrate tools**: Add MCP tools and Composio integrations
5. **Set up skills**: Create reusable skills for your workflows

## Integration with WM Studio

This Kortix deployment will eventually replace the current Director orchestrator in WM Studio. Integration steps:

1. Connect WM Studio MCP tools to Kortix
2. Integrate WM Studio's memory system with Kortix's memory
3. Port WM Studio's skills to Kortix's skill format
4. Update WM Studio's Director runtime to use Kortix API
5. Configure Composio tools in Kortix

## Support

- Kortix Documentation: https://kortix.com/docs
- Kortix GitHub: https://github.com/kortix-ai/suna
- Issues: https://github.com/kortix-ai/suna/issues
