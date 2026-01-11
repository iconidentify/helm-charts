# Helm Charts

Helm charts for the Dialtone platform, managed by Crossplane.

## Charts

| Chart | Description |
|-------|-------------|
| dialtone | AIM-compatible messaging server |
| skalholt | MUD game server |
| mac-connect | Classic Mac emulator (web + relay) |
| nginx-proxy | Reverse proxy for all services |
| netatalk | AFP file server |
| demo-app | Demo frontend/backend/redis |

## Usage

### Install from OCI Registry

```bash
helm install dialtone oci://ghcr.io/iconidentify/charts/dialtone --version 0.1.0 -n dialtone-apps
```

### With Crossplane

Apply the Release resources:

```bash
kubectl apply -f crossplane/releases/
```

## Development

### Package and Push Manually

```bash
export GHCR_USER=iconidentify
export GHCR_TOKEN=your_pat_token
./scripts/package-push.sh 0.1.0
```

### Release via GitHub Actions

Tag a release:

```bash
git tag v0.1.0
git push origin v0.1.0
```

Or use workflow dispatch in GitHub Actions.

## Crossplane Setup

1. Create GHCR credentials secret:

```bash
kubectl create secret generic ghcr-helm-credentials \
  -n crossplane-system \
  --from-literal=credentials='{"auths":{"ghcr.io":{"username":"iconidentify","password":"YOUR_TOKEN"}}}'
```

2. Apply releases:

```bash
kubectl apply -f crossplane/releases/
```

## Migration from Raw Manifests

See the migration guide in each release YAML. Key point: **PVCs are preserved** - charts reference existing PVCs by name, they don't create new ones.
