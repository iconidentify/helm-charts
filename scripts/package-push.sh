#!/bin/bash
# Package and push Helm charts to GHCR OCI registry
set -e

CHART_DIR="/home/chrisk/helm-charts/charts"
REGISTRY="oci://ghcr.io/iconidentify/charts"
VERSION="${1:-0.1.0}"
PACKAGE_DIR="/tmp/helm-packages"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Helm Chart Package and Push Script ===${NC}"
echo "Version: $VERSION"
echo "Registry: $REGISTRY"
echo ""

# Check if GHCR_TOKEN is set
if [ -z "$GHCR_TOKEN" ]; then
    echo -e "${RED}Error: GHCR_TOKEN environment variable is not set${NC}"
    echo "Set it with: export GHCR_TOKEN=your_github_pat_token"
    exit 1
fi

# Check if GHCR_USER is set
if [ -z "$GHCR_USER" ]; then
    echo -e "${RED}Error: GHCR_USER environment variable is not set${NC}"
    echo "Set it with: export GHCR_USER=your_github_username"
    exit 1
fi

# Login to GHCR
echo -e "${YELLOW}Logging in to ghcr.io...${NC}"
echo "$GHCR_TOKEN" | helm registry login ghcr.io -u "$GHCR_USER" --password-stdin

# Create package directory
mkdir -p "$PACKAGE_DIR"

# Charts to process
CHARTS="dialtone skalholt mac-connect nginx-proxy netatalk demo-app"

for chart in $CHARTS; do
    echo ""
    echo -e "${YELLOW}=== Processing $chart ===${NC}"

    # Check if chart exists
    if [ ! -d "$CHART_DIR/$chart" ]; then
        echo -e "${RED}Chart directory not found: $CHART_DIR/$chart${NC}"
        continue
    fi

    # Update version in Chart.yaml
    echo "Updating version to $VERSION..."
    sed -i "s/^version:.*/version: $VERSION/" "$CHART_DIR/$chart/Chart.yaml"

    # Lint the chart
    echo "Linting chart..."
    if ! helm lint "$CHART_DIR/$chart"; then
        echo -e "${RED}Lint failed for $chart${NC}"
        continue
    fi

    # Package the chart
    echo "Packaging chart..."
    helm package "$CHART_DIR/$chart" -d "$PACKAGE_DIR/"

    # Push to OCI registry
    echo "Pushing to $REGISTRY..."
    if helm push "$PACKAGE_DIR/${chart}-${VERSION}.tgz" "$REGISTRY"; then
        echo -e "${GREEN}Successfully pushed $chart:$VERSION${NC}"
    else
        echo -e "${RED}Failed to push $chart${NC}"
    fi
done

echo ""
echo -e "${GREEN}=== Done ===${NC}"
echo ""
echo "Charts are available at:"
for chart in $CHARTS; do
    echo "  $REGISTRY/$chart:$VERSION"
done
echo ""
echo "Next steps:"
echo "1. Create GHCR credentials secret for Crossplane:"
echo "   kubectl create secret generic ghcr-helm-credentials \\"
echo "     -n crossplane-system \\"
echo "     --from-literal=credentials='{\"auths\":{\"ghcr.io\":{\"username\":\"$GHCR_USER\",\"password\":\"YOUR_TOKEN\"}}}'"
echo ""
echo "2. Apply Crossplane Release resources:"
echo "   kubectl apply -f /home/chrisk/helm-charts/crossplane/releases/"
