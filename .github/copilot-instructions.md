# SimpleElasticStack - AI Coding Assistant Instructions

## Project Overview

Single-node Elastic Stack deployment (Elasticsearch, Kibana, Fleet Server) in Docker with automated setup. **Development/testing only** - not production-hardened.

## Architecture

### Service Orchestration with Docker Compose Profiles

Services are deployed in **three distinct phases** using profiles:

1. **Profile: `setup`** (one-time initialization)
   - `elasticsearch-setup`: Generates SSL/TLS certs via `elasticsearch-certutil`, sets kibana_system password
   - `fleet-setup`: Configures Fleet via Kibana API, creates `fleet-server-policy`, generates service token
   - Both exit after completion - **never run with main services**

2. **Profile: `fleet`** (main deployment)
   - `fleet-server`: Elastic Agent in Fleet Server mode, depends on `fleet-setup` output

3. **Default profile** (always active)
   - `elasticsearch`: Single-node, SSL-enabled, exposes 9200/9300
   - `kibana`: Web UI on 5601, custom logging config at `configs/kibana.yml`

**Critical**: The script ensures setup containers complete before starting main services - this sequence is non-negotiable for proper token generation.

### Volume Strategy

**Bind mounts** (not Docker volumes) for `certs/`, `esdata/`, `logs/`:
- Required for `elastic-stack.sh --new` to use `sudo rm -rf` for cleanup
- Directory permissions: 755 (created fresh on `--new`)
- `fleet-data` is the only pure Docker volume (ephemeral Fleet config cache)

## Key Workflows

### Fresh Installation (`./elastic-stack.sh --new`)

**Automated sequence** (170+ lines of orchestration in `elastic-stack.sh`):

1. Cleanup: `sudo rm -rf certs/ esdata/ logs/`, remove volumes
2. Start setup containers: `docker compose --profile setup up -d`
3. Wait for `elasticsearch-setup` exit code 0 (cert generation complete)
4. Wait for `fleet-setup` exit code 0 (Fleet API calls complete)
5. **Token extraction**: Parse `FLEET_SERVER_SERVICE_TOKEN=` from `fleet-setup` logs
6. **Atomic .env update**: Use temp file to prevent duplicate token lines
7. Start services: `docker compose up -d elasticsearch kibana`, then `--profile fleet up -d fleet-server`
8. Health polling: 120s for Elasticsearch, 240s for Kibana, 120s for Fleet Server

**Never** modify this sequence - timing dependencies are critical (e.g., Fleet setup requires Kibana `"level":"available"` status).

### Certificate Management

Certs are **not in Git** - generated during setup:
- CA: `certs/ca/ca.{crt,key}`
- Per-service certs: `certs/{elasticsearch,kibana,fleet-server}/{service}.{crt,key}`
- SANs include: service names, `localhost`, `127.0.0.1`, `${HOST_IP}` from `.env`

**Regeneration trigger**: Any `--new` run recreates all certificates (no rotation mechanism).

### Environment Configuration

**Required in `.env`**:
- `ELASTIC_PASSWORD` / `KIBANA_PASSWORD`: Min 6 chars (enforced by setup container)
- `HOST_IP`: Used in certificate SANs and external access instructions
- `STACK_VERSION` / `STACK_IMAGE`: Image tags (e.g., `9.2.0`, `-wolfi`)

**Auto-generated** (by `elastic-stack.sh`):
- `ENCRYPTION_KEY`, `REPORTING_ENCRYPTION_KEY`, `SECURITY_ENCRYPTION_KEY`: Via `openssl rand -base64 32`
- `FLEET_SERVER_SERVICE_TOKEN`: Extracted from Fleet setup logs

### Fleet Server Token Flow

**Critical pattern** for token management:

```bash
# In fleet-setup.sh
SERVICE_TOKEN=$(curl -X POST -u elastic:$ELASTIC_PASSWORD \
  http://kibana:5601/api/fleet/service_tokens | grep -o '"value":"[^"]*"')

# In elastic-stack.sh (extraction)
SERVICE_TOKEN=$(docker compose logs fleet-setup | \
  grep "FLEET_SERVER_SERVICE_TOKEN=" | tail -1 | cut -d'=' -f2)

# Atomic .env update (prevents duplicates)
grep -v "^FLEET_SERVER_SERVICE_TOKEN=" .env > .env.tmp
echo "FLEET_SERVER_SERVICE_TOKEN=${SERVICE_TOKEN}" >> .env.tmp
mv .env.tmp .env
```

**Why**: Fleet Server won't start without valid token; duplicates cause parsing errors.

## Development Guidelines

### Modifying Services

**docker-compose.yml changes**:
- Respect healthcheck commands - other services depend on `condition: service_healthy`
- All HTTPS services must use `--cacert /path/to/ca/ca.crt` in health checks
- Resource limits: `mem_limit: ${MEM_LIMIT}` (default 4g in `.env`)

### Script Modifications

**elastic-stack.sh patterns**:
- Color output: `print_success`, `print_error`, `print_warning`, `print_info`
- Confirmation prompts: Check for `--force` flag to skip
- Exit codes: Return non-zero on failures for CI integration

### Adding New Services

**Checklist**:
1. Add to `docker-compose.yml` with `networks: - elastic`
2. Create certificates: Add to `instances.yml` in setup container command
3. Update `wait_for_services_healthy()` in `elastic-stack.sh`
4. Document in `README.md` under Architecture section

## Testing Patterns

**Manual verification**:
```bash
# Elasticsearch cluster health
curl -k -u elastic:$ELASTIC_PASSWORD https://localhost:9200/_cluster/health?pretty

# Fleet Server API
curl -k https://localhost:8220/api/status  # Should return {"status":"HEALTHY"}

# Kibana status
curl -s -I http://localhost:5601 | grep "302 Found"
```

**Common failure modes**:
- `elastic-stack.sh --new` fails at token extraction → Check `docker compose logs fleet-setup` for API errors
- Fleet Server unhealthy → Verify `FLEET_SERVER_SERVICE_TOKEN` in `.env` matches Kibana's database
- Permission errors → `sudo chown -R 1000:1000 esdata/` (Elasticsearch runs as UID 1000)

## File Locations

**Critical paths**:
- `elastic-stack.sh`: 579-line management script (main entry point)
- `fleet-setup.sh`: 201-line Kibana API automation (mounted into fleet-setup container)
- `.env.example`: Template with required variables (copy to `.env` before first run)
- `configs/kibana.yml`: Console + file logging configuration
- `docker-compose.yml`: 249 lines, profiles define deployment phases

**Generated at runtime**:
- `certs/*`: SSL/TLS certificates (recreated on `--new`)
- `esdata/*`: Elasticsearch indices/cluster state (persistent between restarts)
- `logs/{elasticsearch,kibana,elastic-agent}/`: Per-service log directories

## Common Pitfalls

1. **Running setup profile with main services**: Always `docker compose down` setup containers before starting fleet
2. **Missing HOST_IP in .env**: Breaks certificate SANs - external agents can't verify Fleet Server
3. **Manual token updates**: Never edit `FLEET_SERVER_SERVICE_TOKEN` manually - use `--new` to regenerate
4. **vm.max_map_count too low**: Elasticsearch requires `sysctl -w vm.max_map_count=262144` on Linux hosts
5. **Port conflicts**: 9200/5601/8220 must be free - check with `sudo lsof -i :PORT`

## CI/CD and Dependency Management

### GitHub Actions Workflows

**`.github/workflows/ci.yml`** - Full stack integration testing:
- Runs on pushes to `main`/`develop` and all PRs
- Executes complete setup sequence (certs → Fleet → services)
- Tests all APIs (Elasticsearch, Kibana, Fleet Server)
- Validates document indexing and search
- Uses reduced resources (`MEM_LIMIT=2g`) for CI environment

**`.github/workflows/pr-validation.yml`** - Quick validation checks:
- Validates `docker-compose.yml` syntax
- Checks shell script syntax (`bash -n`)
- Scans for accidentally committed secrets
- Runs ShellCheck linting
- Validates `.env.example` has required variables

**`.github/workflows/nix-flake-update.yml`** - Automated Nix updates:
- Runs weekly (Mondays 9 AM UTC)
- Executes `nix flake update`
- Creates PR if `flake.lock` changes

### Dependabot Configuration

**`.github/dependabot.yml`**:
- Monitors Docker images in `docker-compose.yml`
- **Groups Elastic Stack updates** (all three images in one PR)
- Weekly checks on Monday mornings
- Note: Nix flakes handled by separate workflow (Dependabot doesn't support Nix natively)

**After Dependabot PRs**: Manually update `STACK_VERSION` in `.env` and `.env.example` to match new image versions.

## References

- `ELASTIC_STACK_SCRIPT.md`: Detailed script behavior and command reference
- `FLEET_SETUP.md`: Fleet Server configuration internals
- `README.md`: User-facing documentation with troubleshooting section
- Elastic official docs: https://www.elastic.co/guide (especially Docker deployment guides)
