# Kortix Deployment for Azure Container Apps

This repository contains the deployment configuration for Kortix/Suna on Azure Container Apps using Docker Compose.

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
   ./deploy-kortix.sh deploy
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

The deployment includes:

- **kortix-api**: Kortix backend API (port 8008)
- **kortix-frontend**: Kortix web frontend (port 3000)
- **redis**: Redis for caching and session management (port 6379)
- **postgres**: PostgreSQL database (port 5432, optional if using Supabase cloud)

## Deployment Script Usage

```bash
# Deploy (build and start)
./deploy-kortix.sh deploy

# Start services
./deploy-kortix.sh start

# Stop services
./deploy-kortix.sh stop

# Restart services
./deploy-kortix.sh restart

# View logs
./deploy-kortix.sh logs

# Check health
./deploy-kortix.sh health

# Deploy to Azure (not yet implemented)
./deploy-kortix.sh azure
```

## Access Points

After deployment:

- **Frontend**: http://localhost:3000
- **API**: http://localhost:8008
- **API Health**: http://localhost:8008/v1/health

## Azure Container Apps Deployment

Currently, this setup uses Docker Compose for local deployment. Azure Container Apps deployment will be added in a future update.

For now, you can:
1. Deploy locally using Docker Compose
2. Use the Azure Container Apps Docker Compose integration (requires Azure CLI)
3. Manually convert the docker-compose.yml to Azure Container Apps YAML

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
