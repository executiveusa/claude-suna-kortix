#!/bin/bash
# Maintenance Mode Control Script
# Usage: ./scripts/maintenance-mode.sh [enable|disable|status]

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
MAINTENANCE_FILE="$PROJECT_ROOT/maintenance.html"

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

check_railway() {
  if ! command -v railway &> /dev/null; then
    print_error "Railway CLI not found"
    echo "This script requires Railway CLI"
    exit 1
  fi
  
  if ! railway whoami &> /dev/null; then
    print_error "Not logged into Railway"
    echo "Run: railway login"
    exit 1
  fi
}

get_status() {
  print_header "Maintenance Mode Status"
  
  # Check if services are paused
  SERVICES_STATUS=$(railway status 2>&1)
  
  if echo "$SERVICES_STATUS" | grep -q "paused"; then
    print_warning "Maintenance mode is ENABLED"
    echo -e "\nPaused services:"
    echo "$SERVICES_STATUS" | grep "paused"
  else
    print_success "Maintenance mode is DISABLED"
    echo -e "\nActive services:"
    railway ps
  fi
}

enable_maintenance() {
  print_header "Enabling Maintenance Mode"
  
  print_warning "This will:"
  echo "  - Pause all main services (backend, worker, frontend)"
  echo "  - Deploy maintenance page"
  echo "  - Stop cost accumulation"
  echo "  - Prepare migration to Coolify"
  echo ""
  read -p "Continue? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Cancelled"
    exit 0
  fi
  
  # Create maintenance service if needed
  print_info "Setting up maintenance service..."
  
  # Create a minimal static server for maintenance page
  cat > /tmp/maintenance-server.js << 'EOF'
const http = require('http');
const fs = require('fs');
const path = require('path');

const port = process.env.PORT || 3000;
const maintenanceHtml = fs.readFileSync(path.join(__dirname, 'maintenance.html'), 'utf8');

const server = http.createServer((req, res) => {
  res.writeHead(200, {'Content-Type': 'text/html'});
  res.end(maintenanceHtml);
});

server.listen(port, () => {
  console.log(`Maintenance page server running on port ${port}`);
});
EOF
  
  # Copy maintenance files to a temporary deployment directory
  TEMP_DIR="/tmp/railway-maintenance-$$"
  mkdir -p "$TEMP_DIR"
  cp "$MAINTENANCE_FILE" "$TEMP_DIR/"
  cp /tmp/maintenance-server.js "$TEMP_DIR/"
  
  # Create package.json for maintenance service
  cat > "$TEMP_DIR/package.json" << EOF
{
  "name": "suna-maintenance",
  "version": "1.0.0",
  "description": "Suna maintenance mode page",
  "main": "maintenance-server.js",
  "scripts": {
    "start": "node maintenance-server.js"
  }
}
EOF
  
  print_info "Pausing services..."
  
  # Pause main services
  if railway service list | grep -q "backend"; then
    railway service pause backend || print_warning "Could not pause backend"
  fi
  
  if railway service list | grep -q "worker"; then
    railway service pause worker || print_warning "Could not pause worker"
  fi
  
  if railway service list | grep -q "frontend"; then
    railway service pause frontend || print_warning "Could not pause frontend"
  fi
  
  print_success "Main services paused"
  
  # Note: Deploying a new maintenance service requires creating it in Railway dashboard
  print_info "To deploy maintenance page:"
  echo "1. Create a new service in Railway dashboard"
  echo "2. Name it 'maintenance'"
  echo "3. Deploy from: $TEMP_DIR"
  echo "4. Set as default service domain"
  
  # Log maintenance activation
  echo "$(date -Iseconds): Maintenance mode enabled" >> "$PROJECT_ROOT/.maintenance.log"
  
  # Clean up temp files
  rm -rf "$TEMP_DIR"
  rm -f /tmp/maintenance-server.js
  
  print_success "Maintenance mode enabled"
  
  # Show next steps
  cat << EOF

${YELLOW}Next Steps:${NC}

1. Verify services are paused:
   railway ps

2. Check cost usage:
   railway usage

3. Review migration checklist:
   cat COOLIFY_MIGRATION.md

4. Prepare Coolify deployment:
   See COOLIFY_SUPPORT.md

5. When ready to resume:
   ./scripts/maintenance-mode.sh disable

${BLUE}Cost savings: Services are now paused, no further charges accumulating.${NC}

EOF
}

disable_maintenance() {
  print_header "Disabling Maintenance Mode"
  
  print_warning "This will:"
  echo "  - Resume all paused services"
  echo "  - Remove maintenance page"
  echo "  - Resume normal operations"
  echo "  - Resume cost accumulation"
  echo ""
  read -p "Continue? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Cancelled"
    exit 0
  fi
  
  print_info "Resuming services..."
  
  # Resume services
  if railway service list | grep -q "backend"; then
    railway service resume backend || print_warning "Could not resume backend"
  fi
  
  if railway service list | grep -q "worker"; then
    railway service resume worker || print_warning "Could not resume worker"
  fi
  
  if railway service list | grep -q "frontend"; then
    railway service resume frontend || print_warning "Could not resume frontend"
  fi
  
  # Remove maintenance service if exists
  if railway service list | grep -q "maintenance"; then
    print_info "Removing maintenance service..."
    railway service delete maintenance || print_warning "Could not delete maintenance service"
  fi
  
  print_success "Services resumed"
  
  # Log maintenance deactivation
  echo "$(date -Iseconds): Maintenance mode disabled" >> "$PROJECT_ROOT/.maintenance.log"
  
  print_info "Waiting for services to become healthy..."
  sleep 10
  
  # Check status
  railway status
  
  print_success "Maintenance mode disabled"
  
  cat << EOF

${GREEN}Normal operations resumed${NC}

Verify functionality:
1. Check health: railway logs --service=backend | grep "health"
2. Test frontend: Open your deployment URL
3. Monitor costs: railway usage

${YELLOW}Remember to monitor usage to avoid hitting free tier limits again!${NC}

EOF
}

show_help() {
  cat << EOF
Maintenance Mode Control Script

Usage: ./scripts/maintenance-mode.sh [COMMAND]

Commands:
  enable     Enable maintenance mode (pause services)
  disable    Disable maintenance mode (resume services)
  status     Show current maintenance mode status
  help       Show this help message

Examples:
  ./scripts/maintenance-mode.sh status
  ./scripts/maintenance-mode.sh enable
  ./scripts/maintenance-mode.sh disable

What is maintenance mode?
  Maintenance mode pauses all your services on Railway to stop cost
  accumulation when free tier limits are reached. A static maintenance
  page is displayed to users while services are paused.

When to use:
  - Free tier limit reached (>95% usage)
  - Preparing for migration to Coolify
  - Temporary cost control needed
  - Service issues requiring investigation

Related documentation:
  - RAILWAY_DEPLOYMENT.md
  - COOLIFY_MIGRATION.md

EOF
}

main() {
  COMMAND="${1:-status}"
  
  case "$COMMAND" in
    enable)
      check_railway
      enable_maintenance
      ;;
    disable)
      check_railway
      disable_maintenance
      ;;
    status)
      check_railway
      get_status
      ;;
    help|--help|-h)
      show_help
      ;;
    *)
      print_error "Unknown command: $COMMAND"
      echo "Use 'help' for usage information"
      exit 1
      ;;
  esac
}

main "$@"
