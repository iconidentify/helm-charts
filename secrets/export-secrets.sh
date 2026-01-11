#!/bin/bash
# Export secrets from Kubernetes cluster to a local file
# Usage: ./export-secrets.sh [output-file]
#
# This script exports all application secrets from your cluster
# so you can back them up or transfer to another installation.

set -e

OUTPUT_FILE="${1:-secrets.env}"

echo "Exporting secrets to: $OUTPUT_FILE"
echo "=================================="

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "ERROR: kubectl not found"
    exit 1
fi

# Check cluster connectivity
if ! kubectl cluster-info &> /dev/null; then
    echo "ERROR: Cannot connect to Kubernetes cluster"
    exit 1
fi

# Create output file with header
cat > "$OUTPUT_FILE" << 'EOF'
# Dialtone Secrets - Exported from Kubernetes
# Generated: $(date)
# KEEP THIS FILE SECURE - DO NOT COMMIT TO GIT!

# ===========================================
# DIALTONE APPLICATION SECRETS
# ===========================================
EOF

# Add actual date
sed -i "s/\$(date)/$(date)/" "$OUTPUT_FILE"

# Function to safely get secret value
get_secret() {
    local namespace=$1
    local secret_name=$2
    local key=$3
    kubectl get secret "$secret_name" -n "$namespace" -o jsonpath="{.data.$key}" 2>/dev/null | base64 -d 2>/dev/null || echo ""
}

# Export dialtone-secrets
echo "Extracting dialtone-secrets..."
{
    echo ""
    echo "GROK_API_KEY=$(get_secret dialtone-apps dialtone-secrets grok-api-key)"
    echo "JWT_SECRET=$(get_secret dialtone-apps dialtone-secrets jwt-secret)"
    echo "X_OAUTH_CLIENT_SECRET=$(get_secret dialtone-apps dialtone-secrets x-oauth-client-secret)"
    echo "DISCORD_OAUTH_CLIENT_SECRET=$(get_secret dialtone-apps dialtone-secrets discord-oauth-client-secret)"
    echo "RESEND_API_KEY=$(get_secret dialtone-apps dialtone-secrets resend-api-key)"
    echo "SKALHOLT_SSO_SECRET=$(get_secret dialtone-apps dialtone-secrets skalholt-sso-secret)"
} >> "$OUTPUT_FILE"

# Export GHCR docker credentials
echo "Extracting ghcr-secret..."
{
    echo ""
    echo "# ===========================================
# DOCKER REGISTRY (GHCR)
# ==========================================="
    # Docker config is JSON, extract username and password
    DOCKER_CONFIG=$(kubectl get secret ghcr-secret -n dialtone-apps -o jsonpath='{.data.\.dockerconfigjson}' 2>/dev/null | base64 -d 2>/dev/null || echo "{}")
    GHCR_USERNAME=$(echo "$DOCKER_CONFIG" | jq -r '.auths["ghcr.io"].username // empty' 2>/dev/null || echo "")
    GHCR_TOKEN=$(echo "$DOCKER_CONFIG" | jq -r '.auths["ghcr.io"].password // empty' 2>/dev/null || echo "")
    echo "GHCR_USERNAME=$GHCR_USERNAME"
    echo "GHCR_TOKEN=$GHCR_TOKEN"
} >> "$OUTPUT_FILE"

# Export TLS certificate info (just note that it exists, don't export private key in plain text)
echo "Checking nginx-tls..."
{
    echo ""
    echo "# ===========================================
# TLS CERTIFICATE
# ===========================================
# TLS cert exists in cluster. To export the actual cert/key:
#   kubectl get secret nginx-tls -n dialtone-apps -o jsonpath='{.data.tls\\.crt}' | base64 -d > tls.crt
#   kubectl get secret nginx-tls -n dialtone-apps -o jsonpath='{.data.tls\\.key}' | base64 -d > tls.key"
    echo "TLS_CERT_FILE=./tls.crt"
    echo "TLS_KEY_FILE=./tls.key"
} >> "$OUTPUT_FILE"

# Export Crossplane helm credentials
echo "Extracting ghcr-helm-credentials..."
{
    echo ""
    echo "# ===========================================
# CROSSPLANE HELM REGISTRY
# ==========================================="
    echo "HELM_REGISTRY_USERNAME=$(get_secret crossplane-system ghcr-helm-credentials username)"
    echo "HELM_REGISTRY_PASSWORD=$(get_secret crossplane-system ghcr-helm-credentials password)"
} >> "$OUTPUT_FILE"

# Set restrictive permissions
chmod 600 "$OUTPUT_FILE"

echo ""
echo "=================================="
echo "Export complete: $OUTPUT_FILE"
echo "File permissions set to 600 (owner read/write only)"
echo ""
echo "WARNING: This file contains sensitive credentials!"
echo "- Store securely (encrypted backup recommended)"
echo "- Never commit to git"
echo "- Delete after transferring to new installation"
