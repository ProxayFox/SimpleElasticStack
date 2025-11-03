# Fleet Server Setup - Complete ✅

## Overview

Successfully automated Fleet Server setup using Kibana API commands and deployed a working Fleet Server container.

## Components Created

### 1. Fleet Setup Script (`fleet-setup.sh`)

Automates Fleet configuration via Kibana API:

- Waits for Kibana to be ready
- Initializes Fleet in Kibana
- Creates Fleet Server policy (`fleet-server-policy`)
- **Configures Fleet Server host** (default: `https://fleet-server:8220`, configurable via `FLEET_SERVER_HOST`)
- **Configures Elasticsearch output** (default: `https://elasticsearch:9200`, configurable via `ELASTICSEARCH_OUTPUT_HOST`)
- **Optionally configures external Fleet Server host** (if `FLEET_SERVER_EXTERNAL_HOST` is set)
- Generates service token for Fleet Server authentication
- Saves configuration for Fleet Server to use

**Status**: ✅ Completed successfully

### Configuration via .env

You can customize Fleet addresses by setting these optional variables in `.env`:

```bash
# Primary Fleet Server host (default: https://fleet-server:8220)
FLEET_SERVER_HOST=https://fleet-server:8220

# Optional: External Fleet Server host for remote agents
FLEET_SERVER_EXTERNAL_HOST=https://192.168.1.100:8220

# Elasticsearch output host (default: https://elasticsearch:9200)
ELASTICSEARCH_OUTPUT_HOST=https://elasticsearch:9200
```

If not set, sensible defaults are used automatically.

### 2. Docker Compose Services

#### fleet-setup Service

- **Purpose**: One-time setup to configure Fleet in Kibana
- **Image**: `docker.elastic.co/elasticsearch/elasticsearch-wolfi:9.1.5`
- **Dependencies**: Kibana (healthy)
- **Status**: ✅ Completed (exits after setup)

#### fleet-server Service

- **Purpose**: Fleet Server for managing Elastic Agents
- **Image**: `docker.elastic.co/elastic-agent/elastic-agent-complete:9.1.5`
- **Port**: 8220 (HTTPS)
- **Dependencies**: Kibana (healthy)
- **Status**: ✅ Running and HEALTHY

## Configuration

### Environment Variables Added to `.env`

```bash
# Fleet Server Configuration
FLEET_SERVER_SERVICE_TOKEN=AAEAAWVsYXN0aWMvZmxlZXQtc2VydmVyL3Rva2VuLTE3NjEyODAwMTI0NTc6YV9ISV9yM0lRYzJBaFNpUHR6ZGNEUQ
```

### Fleet Server Settings (docker-compose.yml)

- `FLEET_SERVER_ENABLE=true`
- `FLEET_SERVER_ELASTICSEARCH_HOST=https://elasticsearch:9200`
- `FLEET_SERVER_ELASTICSEARCH_CA=/certs/ca/ca.crt`
- `FLEET_SERVER_SERVICE_TOKEN=${FLEET_SERVER_SERVICE_TOKEN}`
- `FLEET_SERVER_POLICY_ID=fleet-server-policy`
- `FLEET_INSECURE=true` (for test environment)
- `CERTIFICATE_AUTHORITIES=/certs/ca/ca.crt`

## Verification

### Fleet Server API Status

```bash
curl -sk https://localhost:8220/api/status
# Output: {"name":"fleet-server","status":"HEALTHY"}
```

### Fleet Agent Status in Kibana

```bash
curl -s -u "elastic:${ELASTIC_PASSWORD}" \
  "http://localhost:5601/api/fleet/agents" \
  -H "kbn-xsrf: true"
```

**Agent Details**:

- Agent ID: `28b676a0-bfd7-422f-940a-88e120b12339`
- Type: `PERMANENT`
- Policy: `fleet-server-policy`
- Status: `online` ✅
- Version: `9.1.5`

## Services Status

| Service | Status | Port | Purpose |
|---------|--------|------|---------|
| Elasticsearch | ✅ Healthy | 9200, 9300 | Data storage |
| Kibana | ✅ Healthy | 5601 | UI and Fleet management |
| Fleet Server | ✅ Healthy (online) | 8220 | Agent management |

## Usage

### Access Fleet in Kibana

1. Open Kibana: <http://localhost:5601>
2. Login with `elastic` / `${ELASTIC_PASSWORD}`
3. Navigate to **Management** → **Fleet**
4. You should see Fleet Server enrolled and online

### Enroll Additional Agents

#### For Agents on the Same Host (using localhost)

Use the Fleet Server URL: `https://localhost:8220`

Example enrollment command:

```bash
./elastic-agent install \
  --url=https://localhost:8220 \
  --enrollment-token=<token-from-kibana> \
  --insecure
```

#### For Agents on Remote Hosts

1. First, add an external Fleet Server host in Kibana:

```bash
# Get your host IP from .env file or use:
echo $HOST_IP

# Or manually add via Kibana UI:
# Settings → Fleet → Fleet Server hosts → Add Fleet Server
# URL: https://YOUR_HOST_IP:8220
```

1. Enroll the remote agent:

```bash
./elastic-agent install \
  --url=https://YOUR_HOST_IP:8220 \
  --enrollment-token=<token-from-kibana> \
  --insecure
```

**Note**: Ensure port 8220 is accessible from remote machines (check firewall rules).

## Notes

- **Test Environment**: Using `FLEET_INSECURE=true` to skip certificate verification
- **Production**: Generate proper certificates for Fleet Server
- **Service Token**: Automatically generated and saved to `.env` file
- **Fleet Setup**: Runs once and exits after configuring Fleet in Kibana
- **Fleet Server Host**: Configured to use internal Docker DNS (`fleet-server:8220`)
- **Elasticsearch Output**: Configured to use internal Docker DNS (`elasticsearch:9200`)
- **External Agents**: For agents outside Docker network, add additional Fleet Server host using the host IP

## Troubleshooting

### Check Fleet Server Logs

```bash
docker compose logs fleet-server --tail 100
```

### Check Fleet Setup Logs

```bash
docker compose logs fleet-setup
```

### Restart Fleet Server

```bash
docker compose restart fleet-server
```

### Re-run Fleet Setup

```bash
docker compose up -d --force-recreate --no-deps fleet-setup
```

## Architecture

```text
┌─────────────────┐
│   Kibana UI     │
│   (Port 5601)   │
└────────┬────────┘
         │
         │ Fleet API
         ▼
┌─────────────────┐      ┌──────────────────┐
│  Fleet Server   │◄────►│  Elasticsearch   │
│   (Port 8220)   │      │  (Port 9200)     │
└────────┬────────┘      └──────────────────┘
         │
         │ Agent Enrollment
         │ & Check-ins
         ▼
    ┌─────────┐
    │ Elastic │
    │ Agents  │
    └─────────┘
```

## Verification Commands

### Check Fleet Settings in Kibana

```bash
# Check Fleet Server hosts
curl -s -u "elastic:${ELASTIC_PASSWORD}" \
  -H "kbn-xsrf: true" \
  "http://localhost:5601/api/fleet/fleet_server_hosts" | jq

# Check Elasticsearch outputs
curl -s -u "elastic:${ELASTIC_PASSWORD}" \
  -H "kbn-xsrf: true" \
  "http://localhost:5601/api/fleet/outputs" | jq
```

**Expected Results**:

- Fleet Server host should show: `https://fleet-server:8220`
- Elasticsearch output should show: `https://elasticsearch:9200`

### Via Kibana UI

1. Navigate to **Stack Management → Fleet → Settings**
2. Verify **Fleet Server hosts** shows the configured host
3. Verify **Outputs** shows Elasticsearch with correct host

## Success Criteria ✅

- [x] Fleet initialized in Kibana
- [x] Fleet Server policy created
- [x] **Fleet Server host configured** (`https://fleet-server:8220`)
- [x] **Elasticsearch output configured** (`https://elasticsearch:9200`)
- [x] Service token generated
- [x] Fleet Server container running
- [x] Fleet Server enrolled in Kibana
- [x] Fleet Server status: HEALTHY
- [x] Fleet Server agent status: online
- [x] Fleet Server API responding

All criteria met! Fleet Server is ready to manage Elastic Agents.
