#!/bin/bash
# Check status of all required secrets in the cluster
# Usage: ./check-secrets.sh

echo "Secrets Status Check"
echo "===================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_secret() {
    local namespace=$1
    local name=$2
    local keys=$3

    echo -n "[$namespace] $name: "

    if kubectl get secret "$name" -n "$namespace" &> /dev/null; then
        echo -e "${GREEN}EXISTS${NC}"

        # Check each key
        for key in $keys; do
            local value=$(kubectl get secret "$name" -n "$namespace" -o jsonpath="{.data.$key}" 2>/dev/null)
            if [ -n "$value" ]; then
                local decoded_len=$(echo "$value" | base64 -d 2>/dev/null | wc -c)
                echo -e "  - $key: ${GREEN}set${NC} ($decoded_len bytes)"
            else
                echo -e "  - $key: ${YELLOW}empty${NC}"
            fi
        done
    else
        echo -e "${RED}MISSING${NC}"
    fi
    echo ""
}

echo "=== Application Secrets ==="
echo ""
check_secret "dialtone-apps" "dialtone-secrets" "grok-api-key jwt-secret x-oauth-client-secret discord-oauth-client-secret resend-api-key skalholt-sso-secret"

echo "=== Docker Registry ==="
echo ""
check_secret "dialtone-apps" "ghcr-secret" ".dockerconfigjson"

echo "=== TLS Certificate ==="
echo ""
check_secret "dialtone-apps" "nginx-tls" "tls.crt tls.key"

echo "=== Crossplane Helm Registry ==="
echo ""
check_secret "crossplane-system" "ghcr-helm-credentials" "username password"

echo "===================="
echo "Check complete"
