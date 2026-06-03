#!/usr/bin/env bash
set -euo pipefail

# Kortix Deployment Script for Azure Container Apps
# Similar to wmstudio deployment approach

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
KORTIX_DIR="$PROJECT_ROOT/suna"
DEPLOY_DIR="$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if .env file exists
check_env_file() {
    log_info "Checking environment configuration..."
    
    if [ ! -f "$DEPLOY_DIR/.env" ]; then
        log_warning ".env file not found. Creating from .env.example..."
        cp "$DEPLOY_DIR/.env.example" "$DEPLOY_DIR/.env"
        log_warning "Please edit $DEPLOY_DIR/.env with your configuration before deploying."
        log_warning "Required variables: SUPABASE_URL, SUPABASE_ANON_KEY, OPENROUTER_API_KEY"
        return 1
    fi
    
    log_success "Environment file found"
    return 0
}

# Check if Docker is installed
check_docker() {
    log_info "Checking Docker installation..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        return 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running. Please start Docker."
        return 1
    fi
    
    log_success "Docker is installed and running"
    return 0
}

# Check if Docker Compose is installed
check_docker_compose() {
    log_info "Checking Docker Compose installation..."
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not installed. Please install Docker Compose."
        return 1
    fi
    
    log_success "Docker Compose is installed"
    return 0
}

# Check if Kortix repo exists
check_kortix_repo() {
    log_info "Checking Kortix repository..."
    
    if [ ! -d "$KORTIX_DIR" ]; then
        log_error "Kortix repository not found at $KORTIX_DIR"
        log_info "Cloning Kortix repository..."
        git clone https://github.com/kortix-ai/suna.git "$KORTIX_DIR"
        log_success "Kortix repository cloned"
    else
        log_success "Kortix repository found"
    fi
    
    return 0
}

# Build Docker images
build_images() {
    log_info "Building Kortix Docker images..."
    
    cd "$DEPLOY_DIR"
    
    # Load environment variables
    export $(cat .env | grep -v '^#' | xargs)
    
    # Build images using Docker Compose
    if docker compose version &> /dev/null; then
        docker compose -f docker-compose.yml build
    else
        docker-compose -f docker-compose.yml build
    fi
    
    log_success "Docker images built successfully"
}

# Start services
start_services() {
    log_info "Starting Kortix services..."
    
    cd "$DEPLOY_DIR"
    
    # Load environment variables
    export $(cat .env | grep -v '^#' | xargs)
    
    # Start services using Docker Compose
    if docker compose version &> /dev/null; then
        docker compose -f docker-compose.yml up -d
    else
        docker-compose -f docker-compose.yml up -d
    fi
    
    log_success "Kortix services started"
}

# Stop services
stop_services() {
    log_info "Stopping Kortix services..."
    
    cd "$DEPLOY_DIR"
    
    if docker compose version &> /dev/null; then
        docker compose -f docker-compose.yml down
    else
        docker-compose -f docker-compose.yml down
    fi
    
    log_success "Kortix services stopped"
}

# Check service health
check_health() {
    log_info "Checking service health..."
    
    # Wait for services to be ready
    sleep 10
    
    # Check API
    if curl -f http://localhost:8008/v1/health &> /dev/null; then
        log_success "Kortix API is healthy"
    else
        log_warning "Kortix API health check failed"
    fi
    
    # Check Frontend
    if curl -f http://localhost:3000 &> /dev/null; then
        log_success "Kortix Frontend is healthy"
    else
        log_warning "Kortix Frontend health check failed"
    fi
    
    # Check Redis
    if docker exec kortix-deployment-redis-1 redis-cli ping &> /dev/null 2>&1; then
        log_success "Redis is healthy"
    else
        log_warning "Redis health check failed"
    fi
    
    # Check PostgreSQL (if using local)
    if [ "${DATABASE_URL:-}" == *"localhost"* ] || [ "${DATABASE_URL:-}" == *"127.0.0.1"* ]; then
        if docker exec kortix-deployment-postgres-1 pg_isready -U kortix &> /dev/null 2>&1; then
            log_success "PostgreSQL is healthy"
        else
            log_warning "PostgreSQL health check failed"
        fi
    fi
}

# View logs
view_logs() {
    cd "$DEPLOY_DIR"
    
    if docker compose version &> /dev/null; then
        docker compose -f docker-compose.yml logs -f
    else
        docker-compose -f docker-compose.yml logs -f
    fi
}

# Deploy to Azure Container Apps
deploy_azure() {
    log_info "Deploying to Azure Container Apps..."
    
    log_warning "Azure Container Apps deployment requires Azure CLI and additional configuration."
    log_warning "This feature is not yet implemented."
    log_info "For now, use Docker Compose for local deployment."
    
    return 0
}

# Main function
main() {
    local command="${1:-deploy}"
    
    case "$command" in
        deploy)
            log_info "Starting Kortix deployment..."
            check_docker || exit 1
            check_docker_compose || exit 1
            check_kortix_repo || exit 1
            check_env_file || exit 1
            build_images
            start_services
            check_health
            log_success "Kortix deployment complete!"
            log_info "Frontend: http://localhost:3000"
            log_info "API: http://localhost:8008"
            log_info "API Health: http://localhost:8008/v1/health"
            ;;
        start)
            log_info "Starting Kortix services..."
            check_docker || exit 1
            check_docker_compose || exit 1
            check_env_file || exit 1
            start_services
            check_health
            log_success "Kortix services started"
            ;;
        stop)
            stop_services
            ;;
        restart)
            stop_services
            start_services
            check_health
            ;;
        logs)
            view_logs
            ;;
        health)
            check_health
            ;;
        azure)
            deploy_azure
            ;;
        *)
            echo "Usage: $0 {deploy|start|stop|restart|logs|health|azure}"
            echo ""
            echo "Commands:"
            echo "  deploy   - Build and start all services (default)"
            echo "  start    - Start all services"
            echo "  stop     - Stop all services"
            echo "  restart  - Restart all services"
            echo "  logs     - View service logs"
            echo "  health   - Check service health"
            echo "  azure    - Deploy to Azure Container Apps (not yet implemented)"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
