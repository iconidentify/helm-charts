# Dialtone Platform Installation Guide

This guide walks you through installing the complete Dialtone platform on a fresh Kubernetes cluster.

## Prerequisites

- Kubernetes cluster (tested with k3s, minikube, or standard k8s)
- `kubectl` configured to access your cluster
- `helm` v3.13+ installed
- `gh` CLI (GitHub CLI) authenticated with access to iconidentify repos
- Access to secrets file (exported from existing installation or filled from template)

## Overview

The platform consists of:
- **Crossplane** - Kubernetes-native infrastructure management
- **Dialtone** - AOL v3 protocol server with web management interface
- **Skalholt** - MUD game server
- **Mac-Connect** - 68k Mac emulator (BasiliskII) with web interface
- **Nginx-Proxy** - HTTPS reverse proxy
- **Netatalk** - AFP file sharing server

All applications are deployed via Crossplane Helm Releases from OCI charts stored in ghcr.io.

---

## Step 1: Prepare Secrets

### Option A: From Existing Installation
If you have an exported secrets file from another installation:
```bash
# Your secrets should be in a secure location like:
ls ~/.secrets/dialtone-secrets.env
ls ~/.secrets/tls.crt
ls ~/.secrets/tls.key
```

### Option B: Fresh Installation
Copy the template and fill in values:
```bash
cd /path/to/helm-charts
cp secrets/secrets.env.template ~/.secrets/dialtone-secrets.env
chmod 600 ~/.secrets/dialtone-secrets.env

# Edit and fill in all values
nano ~/.secrets/dialtone-secrets.env
```

Required secrets:
| Secret | Description | How to Generate |
|--------|-------------|-----------------|
| `GROK_API_KEY` | xAI/Grok API key | Get from https://console.x.ai |
| `JWT_SECRET` | JWT signing key | `openssl rand -base64 32` |
| `SKALHOLT_SSO_SECRET` | Shared SSO token | `openssl rand -hex 16` |
| `GHCR_USERNAME` | GitHub username | Your GitHub username |
| `GHCR_TOKEN` | GitHub PAT | Create with `read:packages` scope |
| `HELM_REGISTRY_USERNAME` | Same as GHCR_USERNAME | Your GitHub username |
| `HELM_REGISTRY_PASSWORD` | Same as GHCR_TOKEN | Your GitHub PAT |

Optional secrets (for OAuth features):
- `X_OAUTH_CLIENT_ID`, `X_OAUTH_CLIENT_SECRET` - Twitter/X OAuth
- `DISCORD_OAUTH_CLIENT_ID`, `DISCORD_OAUTH_CLIENT_SECRET` - Discord OAuth
- `RESEND_API_KEY` - Email via Resend

For TLS, either provide existing cert/key files or generate self-signed:
```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ~/.secrets/tls.key \
  -out ~/.secrets/tls.crt \
  -subj "/CN=dialtone.local"
```

---

## Step 2: Install Crossplane

```bash
# Add Crossplane Helm repo
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update

# Create namespace
kubectl create namespace crossplane-system

# Install Crossplane
helm install crossplane crossplane-stable/crossplane \
  --namespace crossplane-system \
  --wait

# Verify Crossplane is running
kubectl get pods -n crossplane-system
# Expected: crossplane and crossplane-rbac-manager pods Running
```

### Install Helm Provider

```bash
# Install the Helm provider for Crossplane
cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-helm
spec:
  package: xpkg.upbound.io/crossplane-contrib/provider-helm:v0.15.0
EOF

# Wait for provider to be healthy
kubectl wait --for=condition=Healthy provider/provider-helm --timeout=120s

# Create ProviderConfig for in-cluster deployment
cat <<EOF | kubectl apply -f -
apiVersion: helm.crossplane.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: InjectedIdentity
EOF

# Grant provider permissions to deploy to any namespace
SA=$(kubectl get sa -n crossplane-system -o name | grep provider-helm | head -1 | cut -d/ -f2)
kubectl create clusterrolebinding provider-helm-admin \
  --clusterrole=cluster-admin \
  --serviceaccount=crossplane-system:$SA \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Crossplane and Helm provider installed successfully"
```

---

## Step 3: Create Namespaces and Secrets

```bash
# Create application namespace
kubectl create namespace dialtone-apps

# Import secrets using the import script
cd /path/to/helm-charts
./secrets/import-secrets.sh ~/.secrets/dialtone-secrets.env

# Verify secrets were created
./secrets/check-secrets.sh
```

Expected output should show all secrets as "EXISTS" with keys "set".

---

## Step 4: Deploy Applications

### Login to GHCR for Helm

```bash
# Login to GitHub Container Registry
gh auth token | helm registry login ghcr.io -u $(gh api user --jq .login) --password-stdin
```

### Apply All Crossplane Releases

```bash
cd /path/to/helm-charts

# Apply all releases at once
kubectl apply -f crossplane/releases/

# Watch deployment progress
watch kubectl get releases
```

Wait until all releases show `SYNCED: True` and `READY: True`.

### Verify Pods

```bash
# Check all pods are running
kubectl get pods -n dialtone-apps

# Expected pods:
# - dialtone-xxx          (1/1 Running)
# - skalholt-xxx          (1/1 Running)
# - mac-connect-relay-xxx (1/1 Running)
# - mac-connect-web-xxx   (1/1 Running)
# - nginx-proxy-xxx       (1/1 Running)
# - netatalk-xxx          (1/1 Running)
```

---

## Step 5: Verify Installation

### Check Services

```bash
kubectl get svc -n dialtone-apps
```

Key services and their NodePorts:
| Service | Port | NodePort | Purpose |
|---------|------|----------|---------|
| dialtone-aim | 5191 | 30190 | AOL AIM protocol |
| dialtone-web | 5200 | 30200 | Web management |
| skalholt-telnet | 8161 | 30161 | Telnet (color) |
| skalholt-telnet-nocolor | 8162 | 30162 | Telnet (no color) |
| skalholt-http | 8163 | - | Internal HTTP API |
| mac-connect-web | 80 | - | Mac emulator web UI (via nginx) |
| nginx | 80,443 | 30080,30443 | HTTP/HTTPS proxy |
| netatalk | 548 | 30548 | AFP file sharing |

### Test Connectivity

```bash
# Get node IP (for single-node clusters)
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

# Test dialtone AIM port
nc -zv $NODE_IP 30190

# Test skalholt telnet
nc -zv $NODE_IP 30161

# Test nginx HTTP
curl -s -o /dev/null -w "%{http_code}" http://$NODE_IP:30080

# Test internal service connectivity
kubectl run test --rm -it --image=busybox --restart=Never -n dialtone-apps -- \
  nc -zv skalholt-telnet.dialtone-apps.svc.cluster.local 8162
```

### Check Dialtone-Skalholt Integration

```bash
# Verify dialtone can reach skalholt
kubectl exec deploy/dialtone -n dialtone-apps -c dialtone -- \
  cat /app/resources/application.properties | grep -E "telnet\.(host|port)|skalholt"

# Verify skalholt has SSO secret configured
kubectl exec deploy/skalholt -n dialtone-apps -- \
  grep dialtoneSpecialToken /app/server.yaml
```

---

## Step 6: Access Applications

### Dialtone Web Interface
- URL: `https://<node-ip>:30443` (via nginx proxy)
- Direct: `http://<node-ip>:30200`

### Skalholt MUD
```bash
telnet <node-ip> 30161   # With colors
telnet <node-ip> 30162   # Without colors
```

### Mac-Connect
- URL: `http://<node-ip>:30080`

### Netatalk (AFP)
- Connect from Mac: `afp://<node-ip>:30548`

---

## Troubleshooting

### Release Not Syncing
```bash
# Check release status
kubectl describe release <name>

# Check Crossplane provider logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-helm
```

### Pod Not Starting
```bash
# Check pod events
kubectl describe pod <pod-name> -n dialtone-apps

# Check init container logs (for envsubst issues)
kubectl logs <pod-name> -n dialtone-apps -c envsubst-config
```

### Secrets Issues
```bash
# Verify secrets exist and have data
./secrets/check-secrets.sh

# Check if secret keys match what charts expect
kubectl get secret dialtone-secrets -n dialtone-apps -o yaml
```

### PVC Issues
```bash
# Check PVC status
kubectl get pvc -n dialtone-apps

# If stuck in Pending, check storage class
kubectl get sc
```

---

## Upgrading

To upgrade charts after pushing new versions to GHCR:

```bash
# Update version in release file
vim crossplane/releases/<app>-release.yaml

# Apply the updated release
kubectl apply -f crossplane/releases/<app>-release.yaml

# Watch rollout
kubectl rollout status deployment/<app> -n dialtone-apps
```

Or trigger a workflow to publish all charts with a new version:
```bash
gh workflow run release.yml --repo iconidentify/helm-charts -f version=0.3.0
```

---

## Teardown

To completely remove all resources:

```bash
# Delete all Crossplane releases (Orphan policy keeps pods running briefly)
kubectl delete -f crossplane/releases/

# Delete the namespace (removes all apps, PVCs, secrets)
kubectl delete namespace dialtone-apps

# Optionally remove Crossplane
helm uninstall crossplane -n crossplane-system
kubectl delete namespace crossplane-system

# Remove Helm provider
kubectl delete provider provider-helm
```

---

## Quick Install Script

For convenience, here's a single script that performs the full installation:

```bash
#!/bin/bash
set -e

SECRETS_FILE="${1:-$HOME/.secrets/dialtone-secrets.env}"
HELM_CHARTS_DIR="${2:-/path/to/helm-charts}"

echo "=== Dialtone Platform Installation ==="
echo "Secrets file: $SECRETS_FILE"
echo "Charts dir: $HELM_CHARTS_DIR"

# Step 1: Install Crossplane
echo "Installing Crossplane..."
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update
kubectl create namespace crossplane-system --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install crossplane crossplane-stable/crossplane \
  --namespace crossplane-system --wait

# Step 2: Install Helm provider
echo "Installing Helm provider..."
cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-helm
spec:
  package: xpkg.upbound.io/crossplane-contrib/provider-helm:v0.15.0
EOF

kubectl wait --for=condition=Healthy provider/provider-helm --timeout=120s

cat <<EOF | kubectl apply -f -
apiVersion: helm.crossplane.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: InjectedIdentity
EOF

sleep 5
SA=$(kubectl get sa -n crossplane-system -o name | grep provider-helm | head -1 | cut -d/ -f2)
kubectl create clusterrolebinding provider-helm-admin \
  --clusterrole=cluster-admin \
  --serviceaccount=crossplane-system:$SA \
  --dry-run=client -o yaml | kubectl apply -f -

# Step 3: Create namespace and import secrets
echo "Creating namespace and importing secrets..."
kubectl create namespace dialtone-apps --dry-run=client -o yaml | kubectl apply -f -
cd "$HELM_CHARTS_DIR"
./secrets/import-secrets.sh "$SECRETS_FILE"

# Step 4: Deploy applications
echo "Deploying applications..."
kubectl apply -f crossplane/releases/

# Step 5: Wait for deployments
echo "Waiting for releases to be ready..."
sleep 10
kubectl wait --for=condition=Ready releases --all --timeout=300s

echo ""
echo "=== Installation Complete ==="
kubectl get releases
kubectl get pods -n dialtone-apps
```

Save as `install.sh` and run:
```bash
chmod +x install.sh
./install.sh ~/.secrets/dialtone-secrets.env /home/chrisk/helm-charts
```
