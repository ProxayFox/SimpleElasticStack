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

echo "Starting Fleet Server setup..."

# Set default Fleet Server host if not provided
FLEET_SERVER_HOST=${FLEET_SERVER_HOST:-"https://fleet-server:8220"}
ELASTICSEARCH_OUTPUT_HOST=${ELASTICSEARCH_OUTPUT_HOST:-"https://elasticsearch:9200"}

echo "Fleet Server Host: ${FLEET_SERVER_HOST}"
echo "Elasticsearch Output Host: ${ELASTICSEARCH_OUTPUT_HOST}"

# Wait for Kibana to be ready
echo "Waiting for Kibana to be available..."
until curl -s -k -u "elastic:${ELASTIC_PASSWORD}" "http://kibana:5601/api/status" | grep -q '"level":"available"'; do
  echo "Kibana not ready yet, waiting..."
  sleep 5
done
echo "Kibana is ready!"

# Check if Fleet is already set up
echo "Checking Fleet setup status..."
FLEET_STATUS=$(curl -s -k -u "elastic:${ELASTIC_PASSWORD}" \
  -H "kbn-xsrf: true" \
  "http://kibana:5601/api/fleet/setup" || echo '{"isReady":false}')

if echo "$FLEET_STATUS" | grep -q '"isReady":true'; then
  echo "Fleet is already set up"
else
  echo "Setting up Fleet..."
  curl -s -k -u "elastic:${ELASTIC_PASSWORD}" \
    -X POST \
    -H "kbn-xsrf: true" \
    -H "Content-Type: application/json" \
    "http://kibana:5601/api/fleet/setup" \
    -d '{}'
  echo "Fleet setup completed"
fi

# Create or get Fleet Server policy
echo "Creating Fleet Server policy..."
POLICY_RESPONSE=$(curl -s -k -u "elastic:${ELASTIC_PASSWORD}" \
  -X POST \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  "http://kibana:5601/api/fleet/agent_policies?sys_monitoring=true" \
  -d '{
    "name": "Fleet Server Policy",
    "description": "Fleet Server policy",
    "namespace": "default",
    "monitoring_enabled": ["logs", "metrics"],
    "has_fleet_server": true
  }' || echo '{}')

POLICY_ID=$(echo "$POLICY_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$POLICY_ID" ]; then
  # Try to get existing Fleet Server policy
  echo "Trying to get existing Fleet Server policy..."
  EXISTING_POLICY=$(curl -s -k -u "elastic:${ELASTIC_PASSWORD}" \
    -H "kbn-xsrf: true" \
    "http://kibana:5601/api/fleet/agent_policies" || echo '{}')
  POLICY_ID=$(echo "$EXISTING_POLICY" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
fi

echo "Fleet Server Policy ID: $POLICY_ID"

# Configure Fleet Server host
echo "Configuring Fleet Server host..."
FLEET_SERVER_HOST_RESPONSE=$(curl -s -k -u "elastic:${ELASTIC_PASSWORD}" \
  -X POST \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  "http://kibana:5601/api/fleet/fleet_server_hosts" \
  -d "{
    \"name\": \"Default Fleet Server\",
    \"host_urls\": [\"${FLEET_SERVER_HOST}\"],
    \"is_default\": true
  }" || echo '{}')

FLEET_HOST_ID=$(echo "$FLEET_SERVER_HOST_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -n "$FLEET_HOST_ID" ]; then
  echo "Fleet Server host configured with ID: $FLEET_HOST_ID"
else
  echo "Fleet Server host may already exist, checking existing hosts..."
  EXISTING_HOSTS=$(curl -s -k -u "elastic:${ELASTIC_PASSWORD}" \
    -H "kbn-xsrf: true" \
    "http://kibana:5601/api/fleet/fleet_server_hosts" || echo '{}')
  echo "Existing Fleet Server hosts: $EXISTING_HOSTS"
fi

# Configure external Fleet Server host if provided
if [ -n "$FLEET_SERVER_EXTERNAL_HOST" ]; then
  echo "Configuring external Fleet Server host: ${FLEET_SERVER_EXTERNAL_HOST}"
  EXTERNAL_HOST_RESPONSE=$(curl -s -k -u "elastic:${ELASTIC_PASSWORD}" \
    -X POST \
    -H "kbn-xsrf: true" \
    -H "Content-Type: application/json" \
    "http://kibana:5601/api/fleet/fleet_server_hosts" \
    -d "{
      \"name\": \"External Fleet Server\",
      \"host_urls\": [\"${FLEET_SERVER_EXTERNAL_HOST}\"],
      \"is_default\": false
    }" || echo '{}')
  
  EXTERNAL_HOST_ID=$(echo "$EXTERNAL_HOST_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
  
  if [ -n "$EXTERNAL_HOST_ID" ]; then
    echo "External Fleet Server host configured with ID: $EXTERNAL_HOST_ID"
  else
    echo "External Fleet Server host may already exist or failed to create"
  fi
fi

# Configure Elasticsearch output
echo "Configuring Elasticsearch output..."
# First, get the default output ID
OUTPUT_RESPONSE=$(curl -s -k -u "elastic:${ELASTIC_PASSWORD}" \
  -H "kbn-xsrf: true" \
  "http://kibana:5601/api/fleet/outputs" || echo '{}')

DEFAULT_OUTPUT_ID=$(echo "$OUTPUT_RESPONSE" | grep -o '"id":"[^"]*","is_default":true' | head -1 | cut -d'"' -f4)

if [ -z "$DEFAULT_OUTPUT_ID" ]; then
  # Try to get any output ID
  DEFAULT_OUTPUT_ID=$(echo "$OUTPUT_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
fi

if [ -n "$DEFAULT_OUTPUT_ID" ]; then
  echo "Found default output ID: $DEFAULT_OUTPUT_ID"
  echo "Updating Elasticsearch output configuration..."
  
  curl -s -k -u "elastic:${ELASTIC_PASSWORD}" \
    -X PUT \
    -H "kbn-xsrf: true" \
    -H "Content-Type: application/json" \
    "http://kibana:5601/api/fleet/outputs/${DEFAULT_OUTPUT_ID}" \
    -d "{
      \"name\": \"default\",
      \"type\": \"elasticsearch\",
      \"hosts\": [\"${ELASTICSEARCH_OUTPUT_HOST}\"],
      \"is_default\": true,
      \"is_default_monitoring\": true,
      \"ca_trusted_fingerprint\": \"\"
    }" || echo "Failed to update output"
  
  echo "Elasticsearch output configured to: ${ELASTICSEARCH_OUTPUT_HOST}"
else
  echo "Warning: Could not find default output ID"
fi

# Generate Fleet Server service token
echo "Generating Fleet Server service token..."
SERVICE_TOKEN_RESPONSE=$(curl -s -k -u "elastic:${ELASTIC_PASSWORD}" \
  -X POST \
  -H "kbn-xsrf: true" \
  "http://kibana:5601/api/fleet/service_tokens" || echo '{}')

SERVICE_TOKEN=$(echo "$SERVICE_TOKEN_RESPONSE" | grep -o '"value":"[^"]*"' | cut -d'"' -f4)

if [ -z "$SERVICE_TOKEN" ]; then
  echo "Failed to generate service token, trying alternative method..."
  # Use elasticsearch API directly
  SERVICE_TOKEN_RESPONSE=$(curl -s -k -u "elastic:${ELASTIC_PASSWORD}" \
    -X POST \
    -H "Content-Type: application/json" \
    "https://elasticsearch:9200/_security/service/elastic/fleet-server/credential/token/fleet-token-1" || echo '{}')
  SERVICE_TOKEN=$(echo "$SERVICE_TOKEN_RESPONSE" | grep -o '"value":"[^"]*"' | cut -d'"' -f4)
fi

echo "Service Token generated successfully"

# Save configuration to file
cat > /tmp/fleet-config.env << EOF
FLEET_SERVER_POLICY_ID=${POLICY_ID}
FLEET_SERVER_SERVICE_TOKEN=${SERVICE_TOKEN}
FLEET_URL=https://fleet-server:8220
FLEET_CA=/usr/share/elastic-agent/config/certs/ca/ca.crt
EOF

echo "Fleet configuration saved to /tmp/fleet-config.env"
cat /tmp/fleet-config.env

echo "Fleet Server setup completed successfully!"
