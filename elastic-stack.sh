# Copyright (C) 2025 Proxay

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.

# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

#!/usr/bin/env bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Functions
print_header() {
  echo -e "${BLUE}================================================${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}================================================${NC}"
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

show_help() {
  cat << EOF
Elastic Stack Management Script

Usage: $0 [COMMAND] [OPTIONS]

Commands:
  --new           Clean setup from scratch (destroys all data)
  --start         Start the stack (normal operation)
  --stop          Stop the stack
  --restart       Restart the stack
  --status        Show stack status
  --logs          Show logs for all services
  --clean         Stop and remove all data (including volumes)
  --help          Show this help message

Options:
  --force         Skip confirmation prompts (use with --new or --clean)
  --follow        Follow logs in real-time (use with --logs)
  --service NAME  Target specific service (use with --logs)

Examples:
  $0 --new                          # Fresh installation (asks for confirmation)
  $0 --new --force                  # Fresh installation (no confirmation)
  $0 --start                        # Start existing stack
  $0 --logs --follow                # Watch logs in real-time
  $0 --logs --service fleet-server  # Show Fleet Server logs
  $0 --clean                        # Complete cleanup (asks for confirmation)
  $0 --clean --force                # Complete cleanup (no confirmation)

EOF
}

generate_encryption_key() {
  # Generate a 32-character base64-encoded random key
  openssl rand -base64 32 | tr -d '\n'
}

check_and_generate_encryption_keys() {
  print_header "Checking Encryption Keys"
  
  local keys_generated=false
  
  # Check for ENCRYPTION_KEY
  if ! grep -q "^ENCRYPTION_KEY=.\+$" .env; then
    print_info "Generating ENCRYPTION_KEY..."
    local encryption_key=$(generate_encryption_key)
    if grep -q "^ENCRYPTION_KEY=" .env; then
      # Update existing empty key
      sed -i "s|^ENCRYPTION_KEY=.*|ENCRYPTION_KEY=${encryption_key}|" .env
    elif grep -q "^# Kibana Encryption Keys" .env; then
      # Add after the comment
      sed -i "/^# Kibana Encryption Keys/a ENCRYPTION_KEY=${encryption_key}" .env
    else
      # Append to file
      echo "ENCRYPTION_KEY=${encryption_key}" >> .env
    fi
    print_success "Generated ENCRYPTION_KEY"
    keys_generated=true
  else
    print_success "ENCRYPTION_KEY exists"
  fi
  
  # Check for REPORTING_ENCRYPTION_KEY
  if ! grep -q "^REPORTING_ENCRYPTION_KEY=.\+$" .env; then
    print_info "Generating REPORTING_ENCRYPTION_KEY..."
    local reporting_key=$(generate_encryption_key)
    if grep -q "^REPORTING_ENCRYPTION_KEY=" .env; then
      sed -i "s|^REPORTING_ENCRYPTION_KEY=.*|REPORTING_ENCRYPTION_KEY=${reporting_key}|" .env
    elif grep -q "^ENCRYPTION_KEY=" .env; then
      sed -i "/^ENCRYPTION_KEY=/a REPORTING_ENCRYPTION_KEY=${reporting_key}" .env
    else
      echo "REPORTING_ENCRYPTION_KEY=${reporting_key}" >> .env
    fi
    print_success "Generated REPORTING_ENCRYPTION_KEY"
    keys_generated=true
  else
    print_success "REPORTING_ENCRYPTION_KEY exists"
  fi
  
  # Check for SECURITY_ENCRYPTION_KEY
  if ! grep -q "^SECURITY_ENCRYPTION_KEY=.\+$" .env; then
    print_info "Generating SECURITY_ENCRYPTION_KEY..."
    local security_key=$(generate_encryption_key)
    if grep -q "^SECURITY_ENCRYPTION_KEY=" .env; then
      sed -i "s|^SECURITY_ENCRYPTION_KEY=.*|SECURITY_ENCRYPTION_KEY=${security_key}|" .env
    elif grep -q "^REPORTING_ENCRYPTION_KEY=" .env; then
      sed -i "/^REPORTING_ENCRYPTION_KEY=/a SECURITY_ENCRYPTION_KEY=${security_key}" .env
    else
      echo "SECURITY_ENCRYPTION_KEY=${security_key}" >> .env
    fi
    print_success "Generated SECURITY_ENCRYPTION_KEY"
    keys_generated=true
  else
    print_success "SECURITY_ENCRYPTION_KEY exists"
  fi
  
  if [ "$keys_generated" = true ]; then
    print_success "All missing encryption keys have been generated"
  fi
}

check_prerequisites() {
  print_header "Checking Prerequisites"
  
  if ! command -v docker &> /dev/null; then
  print_error "Docker is not installed"
  exit 1
  fi
  print_success "Docker is installed"
  
  if ! docker compose version &> /dev/null; then
  print_error "Docker Compose is not installed"
  exit 1
  fi
  print_success "Docker Compose is installed"
  
  if ! command -v openssl &> /dev/null; then
  print_error "OpenSSL is not installed (required for encryption key generation)"
  exit 1
  fi
  print_success "OpenSSL is installed"
  
  if [ ! -f ".env" ]; then
  print_error ".env file not found"
  exit 1
  fi
  print_success ".env file exists"
  
  # Check and generate encryption keys if needed
  check_and_generate_encryption_keys
}

clean_all() {
  print_header "Cleaning All Data"
  
  print_info "Stopping all containers..."
  docker compose --profile fleet --profile setup down --remove-orphans 2>/dev/null || true
  
  print_info "Removing setup containers..."
  docker rm -f elasticsearch-setup fleet-setup 2>/dev/null || true
  
  print_info "Deleting local data directories..."
  if [ -d "certs" ]; then
  print_info "Removing certs directory (may require sudo)..."
  sudo rm -rf certs
  print_success "Deleted certs directory"
  fi
  
  if [ -d "esdata" ]; then
  print_info "Removing esdata directory (may require sudo)..."
  sudo rm -rf esdata
  print_success "Deleted esdata directory"
  fi

  if [ -d "logs" ]; then
  print_info "Removing esdata directory (may require sudo)..."
  sudo rm -rf logs
  print_success "Deleted esdata directory"
  fi
  
  print_info "Removing Docker volumes..."
  docker volume rm simple_elk_certs simple_elk_fleet-data simple_elk_esdata simple_elk_logs 2>/dev/null || true
  print_success "Volumes removed"
  
  print_success "Cleanup completed"
}

new_installation() {
  print_header "Starting Fresh Installation"
  
  local FORCE=false
  
  # Check for --force flag
  for arg in "$@"; do
  if [ "$arg" == "--force" ]; then
    FORCE=true
    break
  fi
  done
  
  # Warning about data loss
  if [ "$FORCE" = false ]; then
  print_warning "⚠️  WARNING: This will DELETE ALL existing data!"
  print_warning "    - All Elasticsearch data (esdata/)"
  print_warning "    - All certificates (certs/)"
  print_warning "    - All logs (logs/)"
  print_warning "    - All Docker volumes"
  echo ""
  read -p "Are you sure you want to continue? (yes/no): " -r
  echo
  if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    print_info "Installation cancelled"
    exit 0
  fi
  else
  print_info "Force mode: Skipping confirmation"
  fi
  
  # Clean everything first
  clean_all
  
  # Create necessary directories with proper permissions
  print_info "Creating fresh directories..."
  mkdir -p certs esdata logs/elasticsearch logs/kibana logs/elastic-agent
  chmod 755 certs esdata logs/elasticsearch logs/kibana logs/elastic-agent
  print_success "Directories created with proper permissions"
  
  # Step 1: Run setup containers
  print_header "Step 1: Running Setup Containers"
  print_info "This will create certificates and configure Fleet..."
  docker compose --profile setup up -d
  
  # Wait for setup to complete
  print_info "Waiting for setup containers to complete..."
  
  # Wait for elasticsearch-setup
  print_info "Waiting for certificate generation..."
  for i in {1..120}; do
    if docker inspect elasticsearch-setup 2>/dev/null | grep -q '"Status": "exited"'; then
      if docker inspect elasticsearch-setup 2>/dev/null | grep -q '"ExitCode": 0'; then
        print_success "Certificates created"
        break
      else
        print_error "Certificate generation failed"
        docker compose logs setup
        exit 1
      fi
    fi
    if [ $i -eq 120 ]; then
      print_error "Certificate generation timed out"
      docker compose logs setup
      exit 1
    fi
    sleep 1
  done
  
  # Wait for fleet-setup
  print_info "Waiting for Fleet setup..."
  for i in {1..120}; do
    if docker inspect fleet-setup 2>/dev/null | grep -q '"Status": "exited"'; then
      if docker inspect fleet-setup 2>/dev/null | grep -q '"ExitCode": 0'; then
        print_success "Fleet setup completed"
        break
      else
        print_error "Fleet setup failed"
        docker compose logs fleet-setup
        exit 1
      fi
    fi
    if [ $i -eq 120 ]; then
      print_error "Fleet setup timed out"
      docker compose logs fleet-setup
      exit 1
    fi
    sleep 1
  done
  
  # Step 2: Extract service token
  print_header "Step 2: Extracting Fleet Service Token"
  
  SERVICE_TOKEN=$(docker compose logs fleet-setup | grep "FLEET_SERVER_SERVICE_TOKEN=" | tail -1 | cut -d'=' -f2)
  
  if [ -z "$SERVICE_TOKEN" ]; then
    print_error "Failed to extract service token"
    print_info "Fleet setup logs:"
    docker compose logs fleet-setup
    exit 1
  fi
  
  print_success "Service token extracted"
  print_info "Token: ${SERVICE_TOKEN:0:20}..."
  
  # Step 3: Update .env file
  print_header "Step 3: Updating .env File"
  
  if grep -q "^FLEET_SERVER_SERVICE_TOKEN=" .env; then
    # Update existing token - use a temp file to ensure clean replacement
    grep -v "^FLEET_SERVER_SERVICE_TOKEN=" .env > .env.tmp
    echo "FLEET_SERVER_SERVICE_TOKEN=${SERVICE_TOKEN}" >> .env.tmp
    mv .env.tmp .env
    print_success "Updated FLEET_SERVER_SERVICE_TOKEN in .env"
  else
    # Add new token
    echo "FLEET_SERVER_SERVICE_TOKEN=${SERVICE_TOKEN}" >> .env
    print_success "Added FLEET_SERVER_SERVICE_TOKEN to .env"
  fi
  
  # Step 4: Restart with new configuration
  print_header "Step 4: Starting Stack with New Configuration"
  
  print_info "Stopping setup containers..."
  docker compose down
  
  print_info "Starting core services (Elasticsearch & Kibana)..."
  docker compose up -d elasticsearch kibana
  
  print_info "Waiting for core services to be ready..."
  sleep 5
  
  print_info "Starting Fleet Server with new token..."
  docker compose --profile fleet up -d fleet-server
  
  # Step 5: Wait for services to be healthy
  print_header "Step 5: Waiting for Services to be Healthy"
  
  print_info "Waiting for Elasticsearch..."
  for i in {1..120}; do
    if docker compose ps elasticsearch 2>/dev/null | grep -q "healthy"; then
      print_success "Elasticsearch is healthy"
      break
    fi
    sleep 2
  done
  
  print_info "Waiting for Kibana..."
  for i in {1..120}; do
    if docker compose ps kibana 2>/dev/null | grep -q "healthy"; then
      print_success "Kibana is healthy"
      break
    fi
    sleep 2
  done
  
  print_info "Waiting for Fleet Server..."
  for i in {1..120}; do
    if docker compose ps fleet-server 2>/dev/null | grep -q "healthy"; then
      print_success "Fleet Server is healthy"
      break
    fi
    if [ $i -eq 120 ]; then
      print_warning "Fleet Server health check timeout, checking logs..."
      docker compose logs fleet-server --tail 20
    fi
    sleep 2
  done
  
  # Final status
  print_header "Installation Complete!"
  show_status
  print_info "Access Kibana at: http://localhost:5601"
  print_info "Username: elastic"
  print_info "Password: (from .env file)"
}

start_stack() {
  print_header "Starting Elastic Stack"
  
  if docker compose ps | grep -q "Up"; then
    print_warning "Stack is already running"
    show_status
    return
  fi
  
  print_info "Starting services..."
  docker compose --profile fleet up -d
  
  print_info "Waiting for services to be ready..."
  sleep 5
  
  show_status
  print_success "Stack started"
}

stop_stack() {
  print_header "Stopping Elastic Stack"
  
  print_info "Stopping services..."
  docker compose down
  
  print_success "Stack stopped"
}

restart_stack() {
  print_header "Restarting Elastic Stack"
  
  stop_stack
  sleep 2
  start_stack
}

show_status() {
  print_header "Stack Status"
  
  docker compose ps
  
  echo ""
  print_info "Service Health:"
  
  # Check Elasticsearch
  if docker compose ps elasticsearch 2>/dev/null | grep -q "healthy"; then
    print_success "Elasticsearch: Healthy"
  elif docker compose ps elasticsearch 2>/dev/null | grep -q "Up"; then
    print_warning "Elasticsearch: Starting..."
  else
    print_error "Elasticsearch: Not running"
  fi
  
  # Check Kibana
  if docker compose ps kibana 2>/dev/null | grep -q "healthy"; then
    print_success "Kibana: Healthy"
  elif docker compose ps kibana 2>/dev/null | grep -q "Up"; then
    print_warning "Kibana: Starting..."
  else
    print_error "Kibana: Not running"
  fi
  
  # Check Fleet Server
  if docker compose ps fleet-server 2>/dev/null | grep -q "healthy"; then
    print_success "Fleet Server: Healthy"
  elif docker compose ps fleet-server 2>/dev/null | grep -q "Up"; then
    print_warning "Fleet Server: Starting..."
  else
    print_error "Fleet Server: Not running"
  fi
}

show_logs() {
  local FOLLOW=""
  local SERVICE=""
  
  # Parse options
  shift # Remove --logs
  while [[ $# -gt 0 ]]; do
    case $1 in
      --follow)
        FOLLOW="-f"
        shift
        ;;
      --service)
        SERVICE="$2"
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done
  
  print_header "Service Logs"
  
  if [ -n "$SERVICE" ]; then
    print_info "Showing logs for: $SERVICE"
    docker compose logs $FOLLOW $SERVICE
  else
    print_info "Showing logs for all services"
    docker compose logs $FOLLOW
  fi
}

# Main script logic
if [ $# -eq 0 ]; then
  show_help
  exit 0
fi

case "$1" in
  --new)
    check_prerequisites
    new_installation "$@"
    ;;
  --start)
    check_prerequisites
    start_stack
    ;;
  --stop)
    check_prerequisites
    stop_stack
    ;;
  --restart)
    check_prerequisites
    restart_stack
    ;;
  --status)
    show_status
    ;;
  --logs)
    show_logs "$@"
    ;;
  --clean)
    check_prerequisites
    
    # Check for --force flag
    local FORCE_CLEAN=false
    for arg in "$@"; do
      if [ "$arg" == "--force" ]; then
        FORCE_CLEAN=true
        break
      fi
    done
    
    if [ "$FORCE_CLEAN" = false ]; then
      print_warning "⚠️  WARNING: This will DELETE ALL data!"
      echo ""
      read -p "Are you sure? (yes/no): " -r
      echo
      if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_info "Cleanup cancelled"
        exit 0
      fi
    fi
    
    clean_all
    ;;
  --help)
    show_help
    ;;
  *)
    print_error "Unknown command: $1"
    echo ""
    show_help
    exit 1
    ;;
esac
