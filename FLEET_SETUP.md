# Fleet Server Setup - Complete ✅

## Overview

Successfully automated Fleet Server setup using Kibana API commands and deployed a working Fleet Server container.

## Components Created

### 1. Fleet Setup Script (`fleet-setup.sh`)

Automates Fleet configuration via Kibana API:

- Waits for Kibana to be ready
- Initializes Fleet in Kibana
- Creates Fleet Server policy (`fleet-server-policy`)
- Generates service token for Fleet Server authentication
- Saves configuration for Fleet Server to use

**Status**: ✅ Completed successfully

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

Use the Fleet Server URL: `https://localhost:8220`

Example enrollment command:

```bash
./elastic-agent install \
  --url=https://localhost:8220 \
  --enrollment-token=<token-from-kibana> \
  --insecure
```

## Notes

- **Test Environment**: Using `FLEET_INSECURE=true` to skip certificate verification
- **Production**: Generate proper certificates for Fleet Server
- **Service Token**: Automatically generated and saved to `.env` file
- **Fleet Setup**: Runs once and exits after configuring Fleet in Kibana

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

## Success Criteria ✅

- [x] Fleet initialized in Kibana
- [x] Fleet Server policy created
- [x] Service token generated
- [x] Fleet Server container running
- [x] Fleet Server enrolled in Kibana
- [x] Fleet Server status: HEALTHY
- [x] Fleet Server agent status: online
- [x] Fleet Server API responding

All criteria met! Fleet Server is ready to manage Elastic Agents.
