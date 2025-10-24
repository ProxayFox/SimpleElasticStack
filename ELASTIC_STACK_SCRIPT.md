# Elastic Stack Management Script

A comprehensive shell script to manage your Elastic Stack deployment (Elasticsearch, Kibana, and Fleet Server) with fully automated setup, token management, and lifecycle operations.

## Features

- ✅ **Fully automated fresh installation** - Complete setup from scratch with one command
- ✅ **Automatic token extraction and management** - Extracts Fleet service token and updates `.env` automatically
- ✅ **Intelligent cleanup** - Safely removes all data directories (certs/, esdata/) with sudo support
- ✅ **Health monitoring** - Waits for all services to be healthy before completion
- ✅ **Colorful output** - Easy-to-read color-coded status messages
- ✅ **Safe operations** - Confirmation prompts before destructive actions
- ✅ **Profile-based deployment** - Uses Docker Compose profiles for clean service separation
- ✅ **Smart dependency management** - Starts services in correct order with proper dependencies

## Quick Reference

| Command | Description |
|---------|-------------|
| `./elastic-stack.sh --new` | Fresh install (asks confirmation) |
| `./elastic-stack.sh --new --force` | Fresh install (no confirmation) |
| `./elastic-stack.sh --start` | Start existing stack |
| `./elastic-stack.sh --stop` | Stop the stack |
| `./elastic-stack.sh --restart` | Restart the stack |
| `./elastic-stack.sh --status` | Show detailed status |
| `./elastic-stack.sh --logs --follow` | Watch all logs live |
| `./elastic-stack.sh --logs --service fleet-server` | View specific service logs |
| `./elastic-stack.sh --clean` | Clean all data (asks confirmation) |
| `./elastic-stack.sh --help` | Show help message |

## Quick Start

### Fresh Installation (from scratch)

```bash
# With confirmation prompt
./elastic-stack.sh --new

# Skip confirmation (automated scripts)
./elastic-stack.sh --new --force
```

**What happens during `--new`:**

1. **Cleanup Phase** - Removes all existing data (requires sudo for directories):
   - Stops all Docker containers
   - Removes Docker volumes: `simple_elk_certs`, `simple_elk_fleet-data`, `simple_elk_esdata`
   - Deletes `certs/` directory (SSL certificates)
   - Deletes `esdata/` directory (Elasticsearch data)

2. **Setup Phase** - Runs setup containers (with Docker Compose `setup` profile):
   - `elasticsearch-setup`: Generates CA and SSL certificates
   - Sets `kibana_system` password in Elasticsearch
   - `fleet-setup`: Initializes Fleet Server in Kibana
   - Creates Fleet Server policy
   - Generates new Fleet service token via Kibana API

3. **Token Management**:
   - Extracts the new service token from `fleet-setup` logs
   - Updates `.env` file with clean token replacement (no duplicates)
   - Validates token format

4. **Service Startup** - Starts services in phases:
   - Phase 1: Elasticsearch & Kibana
   - Phase 2: Fleet Server (with Docker Compose `fleet` profile)
   - Ensures proper dependency order

5. **Health Verification**:
   - Waits up to 120 seconds for Elasticsearch to be healthy
   - Waits up to 240 seconds for Kibana to be healthy
   - Waits up to 120 seconds for Fleet Server to be healthy
   - Displays final status with color-coded health indicators

6. **Completion**:
   - Shows access URLs and credentials
   - All services running and healthy

### Normal Operations

```bash
# Start the stack (uses Docker Compose with --profile fleet)
./elastic-stack.sh --start

# Stop the stack
./elastic-stack.sh --stop

# Restart the stack
./elastic-stack.sh --restart

# Check status with detailed health information
./elastic-stack.sh --status
```

**Note:** The `--start` command automatically includes the `fleet` profile, so Fleet Server will start along with Elasticsearch and Kibana.

### View Logs

```bash
# All services
./elastic-stack.sh --logs

# Follow logs in real-time
./elastic-stack.sh --logs --follow

# Specific service
./elastic-stack.sh --logs --service elasticsearch
./elastic-stack.sh --logs --service kibana
./elastic-stack.sh --logs --service fleet-server
```

### Cleanup

```bash
# Complete cleanup (with confirmation)
./elastic-stack.sh --clean

# Force cleanup (no confirmation)
./elastic-stack.sh --clean --force
```

## What Gets Deleted with `--new` or `--clean`?

### Deleted (Requires sudo for directories)

- ✗ `certs/` directory - All SSL/TLS certificates (CA, node certificates, keys)
- ✗ `esdata/` directory - All Elasticsearch data (indices, cluster state, documents)
- ✗ Docker volumes:
  - `simple_elk_certs` - Certificate storage volume
  - `simple_elk_fleet-data` - Fleet configuration volume
  - `simple_elk_esdata` - Elasticsearch data volume
- ✗ Stopped containers:
  - `elasticsearch-setup` - Certificate generation container
  - `fleet-setup` - Fleet configuration container

### Preserved

- ✓ `.env` file - **Preserved** with automatic `FLEET_SERVER_SERVICE_TOKEN` update
- ✓ `docker-compose.yml` - Configuration file remains unchanged
- ✓ `fleet-setup.sh` - Fleet setup script remains unchanged
- ✓ All other configuration files

## Access Your Stack

After running `--new` or `--start`:

- **Kibana**: <http://localhost:5601>
- **Elasticsearch**: <https://localhost:9200>
- **Fleet Server**: <https://localhost:8220>

**Default Credentials:**

- Username: `elastic`
- Password: Check your `.env` file (`ELASTIC_PASSWORD`)

## Troubleshooting

### Check Service Status

```bash
./elastic-stack.sh --status
```

### View Service Logs

```bash
# All services with live updates
./elastic-stack.sh --logs --follow

# Specific service
./elastic-stack.sh --logs --service fleet-server
```

### Elasticsearch Not Starting

```bash
# Check logs
./elastic-stack.sh --logs --service elasticsearch

# Verify directory permissions
ls -la certs/ esdata/
```

### Fleet Server Authentication Failed

This usually means the service token is outdated or corrupted. The token is generated fresh during setup and stored in `.env`.

**Solution:**

```bash
./elastic-stack.sh --new --force
```

**Why this happens:**

- Old data was wiped but the `.env` file still had the old token
- Token format was corrupted (duplicated lines)
- Setup containers completed but token wasn't extracted properly

The `--new` command regenerates everything including a fresh token.

## Examples

### Development Workflow

```bash
# Initial setup
./elastic-stack.sh --new

# Work on your project...

# Stop when done
./elastic-stack.sh --stop

# Resume work next day
./elastic-stack.sh --start
```

### CI/CD Pipeline

```bash
# Automated fresh install (no prompts)
./elastic-stack.sh --new --force

# Run tests...

# Cleanup
./elastic-stack.sh --clean --force
```

### Debugging Issues

```bash
# Start fresh
./elastic-stack.sh --new

# Watch all logs
./elastic-stack.sh --logs --follow

# In another terminal, check status
./elastic-stack.sh --status
```

## Script Options

| Command | Description | Confirmation Required |
|---------|-------------|----------------------|
| `--new` | Fresh installation from scratch | Yes (unless `--force`) |
| `--start` | Start existing stack | No |
| `--stop` | Stop the stack | No |
| `--restart` | Restart the stack | No |
| `--status` | Show service status | No |
| `--logs` | View logs | No |
| `--clean` | Remove all data | Yes (unless `--force`) |
| `--help` | Show help message | No |

## Flags

| Flag | Use With | Description |
|------|----------|-------------|
| `--force` | `--new`, `--clean` | Skip confirmation prompts |
| `--follow` | `--logs` | Follow logs in real-time |
| `--service NAME` | `--logs` | View specific service logs |

## How It Works

### Docker Compose Profiles

The deployment uses Docker Compose profiles to manage different service groups:

1. **`setup` profile** - One-time setup containers:
   - `setup` (elasticsearch-setup): Generates SSL certificates
   - `fleet-setup`: Configures Fleet Server in Kibana

2. **`fleet` profile** - Fleet Server:
   - `fleet-server`: Fleet Server agent

3. **Default (no profile)** - Core services:
   - `elasticsearch`: Main database
   - `kibana`: Web UI

**Profile Usage:**

```bash
# Run setup containers only
docker compose --profile setup up -d

# Run Fleet Server only
docker compose --profile fleet up -d

# Run everything
docker compose --profile setup --profile fleet up -d

# Run core services only (Elasticsearch + Kibana)
docker compose up -d
```

### Token Management Flow

1. `fleet-setup.sh` script runs inside `fleet-setup` container
2. Script calls Kibana REST API to generate service token
3. Token is saved to `/tmp/fleet-config.env` inside container
4. Script extracts token from container logs: `docker compose logs fleet-setup`
5. Token is written to host `.env` file (clean replacement, no duplicates)
6. Fleet Server container reads token from `.env` via Docker Compose
7. Fleet Server authenticates with Elasticsearch using the token

### Service Dependencies

```text
setup → elasticsearch → kibana → fleet-setup
                                      ↓
                             elasticsearch ← fleet-server
                                  kibana
```

- `setup` generates certificates (must complete first)
- `elasticsearch` needs certificates from `setup`
- `kibana` depends on healthy `elasticsearch`
- `fleet-setup` depends on healthy `kibana`
- `fleet-server` uses token from `fleet-setup` and connects to both `elasticsearch` and `kibana`

## Prerequisites

- **Docker** - Container runtime
- **Docker Compose** - Multi-container orchestration
- **sudo access** - Required to delete `certs/` and `esdata/` directories (owned by root)
- **Bash** - Script interpreter (uses `#!/usr/bin/env bash`)
- **`.env` file** - Must contain:
  - `ELASTIC_PASSWORD` - Password for 'elastic' superuser
  - `KIBANA_PASSWORD` - Password for 'kibana_system' user
  - `ENCRYPTION_KEY` - Kibana encryption key (32+ chars)
  - `REPORTING_ENCRYPTION_KEY` - Kibana reporting key (32+ chars)
  - `SECURITY_ENCRYPTION_KEY` - Kibana security key (32+ chars)
  - Other settings (see `.env.example`)

## Files Modified by Script

- `.env` - Updates `FLEET_SERVER_SERVICE_TOKEN` during `--new`
- `certs/` - Deleted and recreated during `--new`
- `esdata/` - Deleted and recreated during `--new`

## Common Issues and Solutions

### Issue: "Permission denied" when deleting directories

**Problem:** Script can't delete `certs/` or `esdata/` directories.

**Cause:** Directories are owned by root (created by Docker containers).

**Solution:** Script automatically uses `sudo`. You'll be prompted for your password.

```bash
# The script handles this automatically
./elastic-stack.sh --new
```

### Issue: Fleet Server stuck in "health: starting"

**Problem:** Fleet Server never becomes healthy.

**Cause:** Usually an authentication issue with the service token.

**Solution:**

```bash
# Check for authentication errors
docker compose logs fleet-server --tail 50 | grep -i "authentication\|401"

# If you see auth errors, recreate everything
./elastic-stack.sh --new --force
```

### Issue: Setup containers didn't complete

**Problem:** Script times out waiting for setup containers.

**Cause:** Elasticsearch or Kibana took too long to start, or setup failed.

**Solution:**

```bash
# Check setup container logs
docker compose logs setup
docker compose logs fleet-setup

# Clean and retry
./elastic-stack.sh --clean --force
./elastic-stack.sh --new --force
```

### Issue: Token in .env file is corrupted/duplicated

**Problem:** `.env` file has malformed `FLEET_SERVER_SERVICE_TOKEN` line.

**Cause:** Script was interrupted during token update, or manual edits went wrong.

**Solution:**

```bash
# Edit .env and ensure only ONE line with the token:
# FLEET_SERVER_SERVICE_TOKEN=AAEAAWVsYXN0aWMvZm...

# Then recreate Fleet Server
docker compose down
docker compose --profile fleet up -d
```

### Issue: "no such service" errors

**Problem:** Docker Compose can't find services in profiles.

**Cause:** Services are in profiles and not started by default.

**Solution:**

```bash
# Use the script instead of direct docker compose commands
./elastic-stack.sh --start    # Automatically includes fleet profile
./elastic-stack.sh --status   # Shows all services
```

### Issue: Containers keep restarting

**Problem:** Elasticsearch or other services in restart loop.

**Cause:** Could be memory limits, configuration issues, or data corruption.

**Solution:**

```bash
# Check container logs for errors
./elastic-stack.sh --logs --service elasticsearch

# Common fixes:
# 1. Check memory: Elasticsearch needs 2GB+ (set in .env MEM_LIMIT)
# 2. Fresh start:
./elastic-stack.sh --new --force
```

## Testing the Installation

After running `--new`, verify everything works:

```bash
# 1. Check all services are healthy
./elastic-stack.sh --status

# 2. Test Elasticsearch
curl -sk -u "elastic:YOUR_PASSWORD" https://localhost:9200/_cluster/health?pretty

# 3. Test Fleet Server
curl -sk https://localhost:8220/api/status

# 4. Access Kibana
# Open browser: http://localhost:5601
# Login: elastic / YOUR_PASSWORD (from .env)

# 5. Verify Fleet in Kibana
# Navigate to: Management → Fleet → Fleet Server
# You should see one Fleet Server agent online
```

## Support

If you encounter issues:

1. **Check service status:** `./elastic-stack.sh --status`
2. **View logs:** `./elastic-stack.sh --logs --service <service-name>`
3. **Try fresh install:** `./elastic-stack.sh --new`
4. **Check this documentation** for common issues above
5. **Verify prerequisites** are met (Docker, sudo, .env file)

## Advanced Usage

### Manual Fleet Server Restart

If you need to restart just Fleet Server:

```bash
docker compose --profile fleet restart fleet-server
```

### View Token Without Recreating

```bash
# See current token in .env
grep FLEET_SERVER_SERVICE_TOKEN .env

# Extract token from last setup run
docker compose logs fleet-setup | grep "FLEET_SERVER_SERVICE_TOKEN"
```

### Cleanup Without Full Rebuild

```bash
# Just stop and remove containers (keep data)
docker compose --profile fleet --profile setup down

# Remove volumes but keep local directories
docker compose --profile fleet --profile setup down --volumes
```

## Project Structure

```text
simple_elk/
├── elastic-stack.sh           # Main management script
├── docker-compose.yml          # Service definitions with profiles
├── fleet-setup.sh              # Fleet configuration script
├── .env                        # Environment variables (passwords, tokens)
├── ELASTIC_STACK_SCRIPT.md     # This documentation
├── certs/                      # SSL certificates (created by setup)
│   ├── ca/
│   │   ├── ca.crt
│   │   └── ca.key
│   └── elasticsearch/
│       ├── elasticsearch.crt
│       └── elasticsearch.key
└── esdata/                     # Elasticsearch data (created by Elasticsearch)
    ├── nodes/
    └── _state/
```

## License

This script is provided as-is for managing your Elastic Stack deployment.
