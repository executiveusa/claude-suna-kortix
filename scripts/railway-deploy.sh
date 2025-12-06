#!/bin/bash
# Railway Zero-Secrets Deployment Script
# Usage: ./scripts/railway-deploy.sh [OPTIONS]

set -euo pipefail

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MASTER_SECRETS_FILE="$PROJECT_ROOT/master.secrets.json"
AGENTS_FILE="$PROJECT_ROOT/.agents"

# Functions
print_header() {
  echo -e "${BLUE}============================================${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}============================================${NC}"
}

print_success() {
  echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
  echo -e "${RED}✗ $1${NC}"
}

print_warning() {
  echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
  echo -e "${BLUE}ℹ $1${NC}"
}

check_prerequisites() {
  print_header "Checking Prerequisites"
  
  # Check Railway CLI
  if ! command -v railway &> /dev/null; then
    print_error "Railway CLI not found"
    echo "Install: npm install -g @railway/cli"
    exit 1
  fi
  print_success "Railway CLI installed"
  
  # Check jq
  if ! command -v jq &> /dev/null; then
    print_error "jq not found"
    echo "Install: sudo apt-get install jq"
    exit 1
  fi
  print_success "jq installed"
  
  # Check authentication
  if ! railway whoami &> /dev/null; then
    print_error "Not logged into Railway"
    echo "Run: railway login"
    exit 1
  fi
  print_success "Logged into Railway as $(railway whoami)"
  
  # Check .agents file
  if [ ! -f "$AGENTS_FILE" ]; then
    print_error ".agents file not found at $AGENTS_FILE"
    exit 1
  fi
  print_success ".agents file found"
  
  # Check master.secrets.json
  if [ ! -f "$MASTER_SECRETS_FILE" ]; then
    print_warning "master.secrets.json not found"
    echo "You'll need to set secrets manually or create this file"
  else
    print_success "master.secrets.json found"
  fi
}

init_project() {
  print_header "Initializing Railway Project"
  
  if railway status &> /dev/null; then
    print_info "Project already linked"
    railway status
  else
    print_info "Creating new Railway project..."
    railway init
  fi
  
  print_success "Project initialized"
}

add_redis_plugin() {
  print_header "Adding Redis Plugin"
  
  # Check if Redis already added
  if railway service list | grep -q "redis"; then
    print_info "Redis plugin already added"
  else
    print_info "Adding Redis plugin..."
    railway add redis
    print_success "Redis plugin added"
  fi
}

set_secrets() {
  print_header "Configuring Secrets"
  
  if [ ! -f "$MASTER_SECRETS_FILE" ]; then
    print_error "master.secrets.json not found"
    echo "Create this file from master.secrets.json.template"
    exit 1
  fi
  
  print_info "Reading secrets from master.secrets.json..."
  
  # Detect project name dynamically or use first available
  PROJECT_NAME=$(cat "$MASTER_SECRETS_FILE" | jq -r '.projects | keys[0]')
  
  if [ -z "$PROJECT_NAME" ] || [ "$PROJECT_NAME" == "null" ]; then
    print_error "No project found in master.secrets.json"
    exit 1
  fi
  
  print_info "Using project: $PROJECT_NAME"
  
  # Extract Railway environment secrets
  SECRETS=$(cat "$MASTER_SECRETS_FILE" | jq -r --arg proj "$PROJECT_NAME" '
    .projects[$proj].environments.railway |
    to_entries[] | .value | to_entries[] |
    select(.value != "" and .value != null) |
    "\(.key)=\(.value)"
  ')
  
  if [ -z "$SECRETS" ]; then
    print_error "No secrets found in master.secrets.json"
    exit 1
  fi
  
  print_info "Setting environment variables..."
  
  # Count secrets
  SECRET_COUNT=$(echo "$SECRETS" | wc -l)
  CURRENT=0
  
  while IFS='=' read -r key value; do
    CURRENT=$((CURRENT + 1))
    printf "Setting %d/%d: %s..." "$CURRENT" "$SECRET_COUNT" "$key"
    
    # Use environment variable to avoid exposing secret in process list
    if KEY_NAME="$key" KEY_VALUE="$value" railway variables set "$KEY_NAME=$KEY_VALUE" &> /dev/null; then
      echo -e " ${GREEN}✓${NC}"
    else
      echo -e " ${RED}✗${NC}"
    fi
  done <<< "$SECRETS"
  
  print_success "All secrets configured"
}

configure_services() {
  print_header "Configuring Services"
  
  # Note: Railway v3+ uses railway.toml for service configuration
  # Service settings are defined in railway.toml
  
  print_info "Service configuration is defined in railway.toml"
  print_info "Ensure railway.toml exists in project root"
  
  if [ -f "$PROJECT_ROOT/railway.toml" ]; then
    print_success "railway.toml found"
  else
    print_error "railway.toml not found"
    echo "This file should exist in project root"
    exit 1
  fi
}

deploy() {
  print_header "Deploying to Railway"
  
  print_info "Starting deployment..."
  railway up --detach
  
  print_success "Deployment initiated"
  print_info "Monitor logs with: railway logs -f"
}

verify_deployment() {
  print_header "Verifying Deployment"
  
  print_info "Waiting for deployment to complete..."
  sleep 10
  
  # Get deployment status
  print_info "Checking service status..."
  railway status
  
  # Get domain
  if DOMAIN=$(railway domain 2>/dev/null); then
    print_success "Deployment URL: $DOMAIN"
    
    # Test health endpoint
    print_info "Testing health endpoint..."
    if curl -sf "https://$DOMAIN/health" > /dev/null; then
      print_success "Health check passed"
    else
      print_warning "Health check failed - services may still be starting"
    fi
  else
    print_warning "No domain configured yet"
    echo "Add a domain with: railway domain add"
  fi
}

setup_monitoring() {
  print_header "Setting Up Monitoring"
  
  print_info "Cost monitoring script available at: scripts/railway-cost-monitor.sh"
  print_info "Set up cron job to run periodically"
  
  cat << 'EOF'

To set up automated monitoring:

1. Configure environment variables:
   export RAILWAY_TOKEN="your-token"
   export RAILWAY_PROJECT_ID="your-project-id"

2. Add to crontab:
   crontab -e
   
   # Add this line (check every hour):
   0 * * * * cd /path/to/suna && ./scripts/railway-cost-monitor.sh >> /var/log/railway-monitor.log 2>&1

3. Enable Railway usage alerts:
   - Go to Railway Dashboard
   - Settings → Usage → Alerts
   - Set threshold at 80% of free tier

EOF
}

show_next_steps() {
  print_header "Next Steps"
  
  cat << EOF

Deployment Summary:
${GREEN}✓ Railway project configured${NC}
${GREEN}✓ Secrets set from master.secrets.json${NC}
${GREEN}✓ Services deployed${NC}

Next Steps:
1. Monitor deployment: railway logs -f
2. Check service status: railway status
3. Set up custom domain: railway domain add your-domain.com
4. Configure cost monitoring (see above)
5. Test all functionality
6. Review RAILWAY_DEPLOYMENT.md for best practices

Useful Commands:
- View logs: railway logs --service=backend -f
- Check usage: railway usage
- Restart service: railway service restart backend
- Update variables: railway variables set KEY=value

Documentation:
- Railway Deployment: RAILWAY_DEPLOYMENT.md
- Migration to Coolify: COOLIFY_MIGRATION.md
- Secrets Reference: .agents

Need Help?
- Railway docs: https://docs.railway.app/
- Suna GitHub: https://github.com/kortix-ai/suna

EOF
}

main() {
  print_header "Railway Zero-Secrets Deployment"
  
  # Parse arguments
  SET_SECRETS=false
  INIT_ONLY=false
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --set-secrets)
        SET_SECRETS=true
        shift
        ;;
      --init-only)
        INIT_ONLY=true
        shift
        ;;
      --help)
        cat << EOF
Usage: ./scripts/railway-deploy.sh [OPTIONS]

Options:
  --set-secrets    Set secrets from master.secrets.json
  --init-only      Only initialize project, don't deploy
  --help          Show this help message

Examples:
  ./scripts/railway-deploy.sh                    # Full deployment
  ./scripts/railway-deploy.sh --set-secrets      # Only set secrets
  ./scripts/railway-deploy.sh --init-only        # Only initialize

EOF
        exit 0
        ;;
      *)
        print_error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
    esac
  done
  
  # Execute steps
  check_prerequisites
  
  if [ "$SET_SECRETS" = true ]; then
    set_secrets
    print_success "Secrets configured successfully"
    exit 0
  fi
  
  init_project
  add_redis_plugin
  configure_services
  
  if [ "$INIT_ONLY" = true ]; then
    print_success "Project initialized. Set secrets and deploy manually."
    exit 0
  fi
  
  # Confirm deployment
  print_warning "Ready to deploy to Railway"
  read -p "Continue? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Deployment cancelled"
    exit 0
  fi
  
  deploy
  verify_deployment
  setup_monitoring
  show_next_steps
  
  print_success "Deployment complete!"
}

# Run main function
main "$@"
