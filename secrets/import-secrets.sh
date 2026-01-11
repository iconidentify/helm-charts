#!/bin/bash
# Import/create secrets in Kubernetes cluster from a local file
# Usage: ./import-secrets.sh [secrets-file]
#
# This script creates all required secrets for the Dialtone platform
# from a secrets.env file.

set -e

SECRETS_FILE="${1:-secrets.env}"

echo "Importing secrets from: $SECRETS_FILE"
echo "========================================"

# Check if secrets file exists
if [ ! -f "$SECRETS_FILE" ]; then
    echo "ERROR: Secrets file not found: $SECRETS_FILE"
    echo "Copy secrets.env.template to secrets.env and fill in values"
    exit 1
fi

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "ERROR: kubectl not found"
    exit 1
fi

# Load secrets from file
set -a
source "$SECRETS_FILE"
set +a

# Validate required secrets
echo "Validating required secrets..."
MISSING=0

check_required() {
    local var_name=$1
    local var_value="${!var_name}"
    if [ -z "$var_value" ]; then
        echo "  MISSING: $var_name"
        MISSING=1
    else
        echo "  OK: $var_name"
    fi
}

check_required "GROK_API_KEY"
check_required "JWT_SECRET"
check_required "GHCR_USERNAME"
check_required "GHCR_TOKEN"
check_required "HELM_REGISTRY_USERNAME"
check_required "HELM_REGISTRY_PASSWORD"

if [ $MISSING -eq 1 ]; then
    echo ""
    echo "WARNING: Some required secrets are missing."
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Create namespaces if they don't exist
echo ""
echo "Ensuring namespaces exist..."
kubectl create namespace dialtone-apps --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace crossplane-system --dry-run=client -o yaml | kubectl apply -f -

# Create dialtone-secrets
echo ""
echo "Creating dialtone-secrets..."
kubectl create secret generic dialtone-secrets \
    --namespace dialtone-apps \
    --from-literal=grok-api-key="${GROK_API_KEY:-}" \
    --from-literal=jwt-secret="${JWT_SECRET:-}" \
    --from-literal=x-oauth-client-secret="${X_OAUTH_CLIENT_SECRET:-}" \
    --from-literal=discord-oauth-client-secret="${DISCORD_OAUTH_CLIENT_SECRET:-}" \
    --from-literal=resend-api-key="${RESEND_API_KEY:-}" \
    --from-literal=skalholt-sso-secret="${SKALHOLT_SSO_SECRET:-}" \
    --dry-run=client -o yaml | kubectl apply -f -
echo "  Created: dialtone-secrets"

# Create ghcr-secret (Docker registry)
echo ""
echo "Creating ghcr-secret..."
if [ -n "$GHCR_USERNAME" ] && [ -n "$GHCR_TOKEN" ]; then
    kubectl create secret docker-registry ghcr-secret \
        --namespace dialtone-apps \
        --docker-server=ghcr.io \
        --docker-username="${GHCR_USERNAME}" \
        --docker-password="${GHCR_TOKEN}" \
        --dry-run=client -o yaml | kubectl apply -f -
    echo "  Created: ghcr-secret"
else
    echo "  SKIPPED: ghcr-secret (missing credentials)"
fi

# Create nginx-tls (if cert files provided)
echo ""
echo "Creating nginx-tls..."
if [ -n "$TLS_CERT_FILE" ] && [ -n "$TLS_KEY_FILE" ] && [ -f "$TLS_CERT_FILE" ] && [ -f "$TLS_KEY_FILE" ]; then
    kubectl create secret tls nginx-tls \
        --namespace dialtone-apps \
        --cert="$TLS_CERT_FILE" \
        --key="$TLS_KEY_FILE" \
        --dry-run=client -o yaml | kubectl apply -f -
    echo "  Created: nginx-tls"
else
    echo "  SKIPPED: nginx-tls (cert files not found)"
    echo "  To create manually:"
    echo "    kubectl create secret tls nginx-tls -n dialtone-apps --cert=tls.crt --key=tls.key"
fi

# Create ghcr-helm-credentials (Crossplane)
echo ""
echo "Creating ghcr-helm-credentials..."
if [ -n "$HELM_REGISTRY_USERNAME" ] && [ -n "$HELM_REGISTRY_PASSWORD" ]; then
    kubectl create secret generic ghcr-helm-credentials \
        --namespace crossplane-system \
        --from-literal=username="${HELM_REGISTRY_USERNAME}" \
        --from-literal=password="${HELM_REGISTRY_PASSWORD}" \
        --dry-run=client -o yaml | kubectl apply -f -
    echo "  Created: ghcr-helm-credentials"
else
    echo "  SKIPPED: ghcr-helm-credentials (missing credentials)"
fi

echo ""
echo "========================================"
echo "Import complete!"
echo ""
echo "Verify secrets with:"
echo "  kubectl get secrets -n dialtone-apps"
echo "  kubectl get secrets -n crossplane-system | grep ghcr"
