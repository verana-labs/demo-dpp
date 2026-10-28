#!/usr/bin/env bash
# =============================================================================
# Verifier VS — Local Setup (Verana v0.10.1+, devnet only)
# =============================================================================
#
# Sets up the operator-run verification service (decision D8) as a delegated
# child of dpp-vs:
#   1. Imports the Corporation operator (dpp-vs) and this agent's accounts
#   2. Joins dpp-vs's Corporation
#   3. Deploys the VS Agent (AGENT_MODE=delegated) via Docker + ngrok
#   4. Provisions Service HOLDER entry + validates Service credential on dpp-vs
#   5. Self-creates VERIFIER on the DPP schema (OPEN onboarding)
#
# Prerequisites:
#   - Docker, ngrok (authenticated), curl, jq, veranad
#   - MNEMONIC (or DPP_VS_MNEMONIC) — Corporation operator
#   - AGENT_MNEMONIC (or VERIFIER_VS_AGENT_MNEMONIC) — this agent
#   - dpp-vs running (admin API + public URL)
#
# Usage:
#   source verifier-vs/config.env
#   MNEMONIC="..." AGENT_MNEMONIC="..." ./verifier-vs/scripts/setup.sh
#
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$SERVICE_DIR/.." && pwd)"

# shellcheck source=../../common/common.sh
source "${REPO_ROOT}/common/common.sh"

NETWORK="${NETWORK:-devnet}"
VS_AGENT_IMAGE="${VS_AGENT_IMAGE:-veranalabs/vs-agent:v2.0.0-dev.97}"
VS_AGENT_CONTAINER_NAME="${VS_AGENT_CONTAINER_NAME:-verifier-vs}"
VS_AGENT_ADMIN_PORT="${VS_AGENT_ADMIN_PORT:-3012}"
VS_AGENT_PUBLIC_PORT="${VS_AGENT_PUBLIC_PORT:-3013}"
VS_AGENT_DATA_DIR="${VS_AGENT_DATA_DIR:-${SERVICE_DIR}/data}"
SERVICE_NAME="${SERVICE_NAME:-DPP Verification Service (demo)}"
USER_ACC="${USER_ACC:-dpp-vs-devnet-admin}"
AGENT_ACC="${AGENT_ACC:-verifier-vs-devnet-agent}"
OUTPUT_FILE="${OUTPUT_FILE:-${SERVICE_DIR}/ids.env}"
MNEMONIC="${MNEMONIC:-${DPP_VS_MNEMONIC:-}}"
AGENT_MNEMONIC="${AGENT_MNEMONIC:-${VERIFIER_VS_AGENT_MNEMONIC:-}}"

DPP_VS_ADMIN_URL="${DPP_VS_ADMIN_URL:-http://localhost:3000}"
DPP_VS_PUBLIC_URL="${DPP_VS_PUBLIC_URL:-}"

SERVICE_TYPE="${SERVICE_TYPE:-WEB_PORTAL}"
SERVICE_DESCRIPTION="${SERVICE_DESCRIPTION:-Verification service for the Digital Product Passport ecosystem}"

if ! command -v veranad &> /dev/null; then
  log "veranad not found — downloading..."
  VERANAD_VERSION="${VERANAD_VERSION:-v0.10.5}"
  PLATFORM="$(uname -s | tr '[:upper:]' '[:lower:]')"
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64)  ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
  esac
  mkdir -p "${HOME}/.local/bin"
  curl -sfL "https://github.com/verana-labs/verana-node/releases/download/${VERANAD_VERSION}/veranad-${PLATFORM}-${ARCH}" \
    -o "${HOME}/.local/bin/veranad"
  chmod +x "${HOME}/.local/bin/veranad"
  export PATH="${HOME}/.local/bin:$PATH"
  ok "veranad installed: $(veranad version)"
fi

set_network_vars "$NETWORK"
log "Network: $NETWORK (chain: $CHAIN_ID)"

ADMIN_API="http://localhost:${VS_AGENT_ADMIN_PORT}"

if ! curl -sf "${DPP_VS_ADMIN_URL}/v2/agent/health/live" > /dev/null 2>&1; then
  err "dpp-vs admin API not reachable at ${DPP_VS_ADMIN_URL}"
  exit 1
fi
ok "dpp-vs admin API reachable: $DPP_VS_ADMIN_URL"

DPP_PUBLIC_API="${DPP_VS_PUBLIC_URL:-http://localhost:${DPP_VS_PUBLIC_PORT:-3001}}"
DPP_DID=$(fetch_did_from_log "$DPP_PUBLIC_API")
if [ -z "$DPP_DID" ]; then
  err "Could not fetch dpp-vs DID from $DPP_PUBLIC_API"
  exit 1
fi
ok "dpp-vs DID: $DPP_DID"

log "Step 1: Import accounts"

if [ -n "${MNEMONIC:-}" ]; then
  echo "$MNEMONIC" | veranad keys add "$USER_ACC" --recover --keyring-backend test 2>/dev/null || true
fi
if ! veranad keys show "$USER_ACC" --keyring-backend test > /dev/null 2>&1; then
  err "No MNEMONIC provided and account '$USER_ACC' does not exist."
  exit 1
fi
require_user_acc_addr || exit 1
ok "Corporation operator: $USER_ACC_ADDR"

if [ -n "${AGENT_MNEMONIC:-}" ]; then
  echo "$AGENT_MNEMONIC" | veranad keys add "$AGENT_ACC" --recover --keyring-backend test 2>/dev/null || true
fi
if ! veranad keys show "$AGENT_ACC" --keyring-backend test > /dev/null 2>&1; then
  err "No AGENT_MNEMONIC provided and account '$AGENT_ACC' does not exist."
  exit 1
fi
AGENT_ADDR=$(veranad keys show "$AGENT_ACC" -a --keyring-backend test)
ok "Agent account (vs_operator): $AGENT_ADDR"

if [ -n "${MNEMONIC:-}" ] && [ "$AGENT_MNEMONIC" = "$MNEMONIC" ]; then
  err "AGENT_MNEMONIC equals MNEMONIC — they must be different accounts."
  exit 1
fi

log "Step 2: Corporation"
resolve_corporation_for_did "$DPP_DID" || exit 1
ok "Joining Corporation $CORPORATION_ID"

log "Step 3: Deploy VS Agent"

docker rm -f "$VS_AGENT_CONTAINER_NAME" 2>/dev/null || true
rm -rf "${VS_AGENT_DATA_DIR}/data/wallet"

log "Pulling VS Agent image..."
if ! docker pull --platform linux/amd64 "$VS_AGENT_IMAGE" 2>&1 | tail -1; then
  if docker image inspect "$VS_AGENT_IMAGE" > /dev/null 2>&1; then
    warn "Pull failed — using locally cached image: $VS_AGENT_IMAGE"
  else
    err "Pull failed and no local image found for: $VS_AGENT_IMAGE"
    exit 1
  fi
fi

log "Starting ngrok tunnel on port ${VS_AGENT_PUBLIC_PORT}..."
pkill -f "ngrok http ${VS_AGENT_PUBLIC_PORT}" 2>/dev/null || true
sleep 1
ngrok http "$VS_AGENT_PUBLIC_PORT" --log=stdout > /tmp/ngrok-verifier-vs.log 2>&1 &
NGROK_PID=$!
sleep 5

NGROK_URL=$(curl -sf http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url // empty')
if [ -z "$NGROK_URL" ]; then
  err "Failed to get ngrok URL. Is ngrok installed and authenticated?"
  exit 1
fi
ok "ngrok tunnel: $NGROK_URL"

log "Starting VS Agent container..."
mkdir -p "$VS_AGENT_DATA_DIR"
docker run --platform linux/amd64 -d \
  -p "${VS_AGENT_PUBLIC_PORT}:3001" \
  -p "${VS_AGENT_ADMIN_PORT}:3000" \
  -v "${VS_AGENT_DATA_DIR}:/root/.afj" \
  -e "PUBLIC_API_BASE_URL=${NGROK_URL}" \
  -e "AGENT_PUBLIC_DID_METHOD=webvh" \
  -e "AGENT_LABEL=${SERVICE_NAME}" \
  -e "ENABLE_PUBLIC_API_SWAGGER=true" \
  -e "VERANA_RPC_ENDPOINT_URL=${NODE_RPC}" \
  -e "VERANA_GAS_PRICE=${VERANA_GAS_PRICE:-0.01uvna}" \
  -e "VERANA_INDEXER_BASE_URL=${INDEXER_URL}" \
  -e "VERANA_CHAIN_ID=${CHAIN_ID}" \
  -e "VERANA_ACCOUNT_MNEMONIC=${AGENT_MNEMONIC}" \
  -e "VERANA_CORPORATION_ID=${CORPORATION_ID}" \
  -e "AGENT_MODE=delegated" \
  -e "AGENT_DELEGATED_PARENT_VS_DID=${DPP_DID}" \
  -e "ECS_CLAIMS_SERVICE_NAME=${SERVICE_NAME}" \
  -e "ECS_CLAIMS_SERVICE_TYPE=${SERVICE_TYPE}" \
  -e "ECS_CLAIMS_SERVICE_DESCRIPTION=${SERVICE_DESCRIPTION}" \
  -e "ECS_CLAIMS_SERVICE_LOGO_URI=${SERVICE_LOGO_URI:-https://verana.io/logo.svg}" \
  -e "ECS_CLAIMS_SERVICE_MINIMUM_AGE_REQUIRED=18" \
  -e "ECS_CLAIMS_SERVICE_TERMS_AND_CONDITIONS_URI=${NGROK_URL}/vt/default/terms.html" \
  -e "ECS_CLAIMS_SERVICE_PRIVACY_POLICY_URI=${NGROK_URL}/vt/default/privacy.html" \
  --name "$VS_AGENT_CONTAINER_NAME" \
  "$VS_AGENT_IMAGE"

ok "VS Agent container started: $VS_AGENT_CONTAINER_NAME"

log "Waiting for VS Agent to initialize (up to 180s)..."
if wait_for_agent "$ADMIN_API" 90; then
  ok "VS Agent is ready"
else
  err "VS Agent did not start within timeout"
  docker logs "$VS_AGENT_CONTAINER_NAME" 2>&1 | tail -20
  exit 1
fi

AGENT_DID=$(curl -sf "${ADMIN_API}/v2/agent/info" | jq -r '.did')
if [ -z "$AGENT_DID" ] || [ "$AGENT_DID" = "null" ]; then
  err "Could not retrieve agent DID"
  exit 1
fi
ok "Agent DID: $AGENT_DID"

log "Step 4: Service credential (delegated onboarding process)"

ECS_SERVICE_SCHEMA_ID=$(find_ecs_schema_id "$ECS_ECOSYSTEM_DID" "ServiceCredential")

if find_participant_with_vs_operator "$ECS_SERVICE_SCHEMA_ID" "$PP_ROLE_HOLDER" "$AGENT_DID" \
     | grep -q "$AGENT_ADDR"; then
  ok "Service HOLDER entry already names $AGENT_ADDR"
else
  DPP_SERVICE_ISSUER_ID=$(find_active_participant \
    "$ECS_SERVICE_SCHEMA_ID" "$PP_IDX_ROLE_ISSUER" "$DPP_DID") || {
    err "dpp-vs holds no active Service ISSUER entry"
    exit 1
  }
  start_participant_op "$CORPORATION" "$PP_ROLE_HOLDER" "$DPP_SERVICE_ISSUER_ID" \
    "$AGENT_DID" "$AGENT_ADDR" "$VSOA_HOLDER" > /dev/null

  log "Waiting for the agent to send its onboarding request..."
  sleep 20
  validate_pending_flow "$DPP_VS_ADMIN_URL" "$AGENT_DID" || {
    err "Could not validate the Service credential onboarding"
    exit 1
  }
fi

log "Step 5: Obtain VERIFIER participant for the DPP schema"

CUSTOM_SCHEMA_ID=$(discover_custom_schema_id "${DPP_PUBLIC_API}/.well-known/did.json") || {
  err "Could not discover the DPP schema from dpp-vs's DID document"
  exit 1
}
ok "DPP schema ID: $CUSTOM_SCHEMA_ID"

if EXISTING_PARTICIPANT_ID=$(find_active_participant "$CUSTOM_SCHEMA_ID" "$PP_IDX_ROLE_VERIFIER" "$AGENT_DID"); then
  ok "Active VERIFIER participant already exists: $EXISTING_PARTICIPANT_ID — skipping"
  VERIFIER_PARTICIPANT_ID="$EXISTING_PARTICIPANT_ID"
else
  ROOT_PARTICIPANT_ID=$(find_root_participant "$CUSTOM_SCHEMA_ID") || {
    err "Could not find the root participant for schema $CUSTOM_SCHEMA_ID"
    exit 1
  }
  # VERIFIER onboarding is OPEN: one transaction, no handshake, no validation.
  VERIFIER_PARTICIPANT_ID=$(self_create_participant "$CORPORATION" "$PP_ROLE_VERIFIER" \
    "$ROOT_PARTICIPANT_ID" "$AGENT_DID" "$AGENT_ADDR" "$VSOA_VERIFIER")
  ok "VERIFIER participant: $VERIFIER_PARTICIPANT_ID"
fi

log "Saving resource IDs to ${OUTPUT_FILE}"

cat > "$OUTPUT_FILE" <<EOF
# Verifier VS — Resource IDs
# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
# Network: ${NETWORK}

AGENT_DID=${AGENT_DID}
NGROK_URL=${NGROK_URL}
VS_AGENT_CONTAINER_NAME=${VS_AGENT_CONTAINER_NAME}
VS_AGENT_ADMIN_PORT=${VS_AGENT_ADMIN_PORT}
VS_AGENT_PUBLIC_PORT=${VS_AGENT_PUBLIC_PORT}
USER_ACC=${USER_ACC}
CORPORATION_ID=${CORPORATION_ID}
CUSTOM_SCHEMA_ID=${CUSTOM_SCHEMA_ID:-}
VERIFIER_PARTICIPANT_ID=${VERIFIER_PARTICIPANT_ID:-}
EOF

ok "IDs saved to ${OUTPUT_FILE}"

log "Verifier VS setup complete!"
echo ""
echo "  Agent DID           : $AGENT_DID"
echo "  Public URL          : $NGROK_URL"
echo "  Admin API           : $ADMIN_API"
echo "  Corporation ID      : $CORPORATION_ID"
echo "  Schema ID           : ${CUSTOM_SCHEMA_ID:-n/a}"
echo "  Verifier Participant: ${VERIFIER_PARTICIPANT_ID:-n/a}"
echo ""
echo "  To stop:"
echo "    docker stop $VS_AGENT_CONTAINER_NAME"
echo "    kill $NGROK_PID  # ngrok"
echo ""
