# Secrets Management

This directory contains tools for managing Kubernetes secrets across Dialtone installations.

## Quick Start

### New Installation

1. Copy the template:
   ```bash
   cp secrets.env.template secrets.env
   ```

2. Edit `secrets.env` and fill in all values

3. Run the import script:
   ```bash
   ./import-secrets.sh secrets.env
   ```

### Backup Existing Installation

```bash
./export-secrets.sh secrets-backup.env
```

### Check Current Status

```bash
./check-secrets.sh
```

## Files

| File | Purpose |
|------|---------|
| `secrets.env.template` | Template showing all required secrets |
| `secrets.env` | Your actual secrets (gitignored) |
| `export-secrets.sh` | Export secrets from cluster to file |
| `import-secrets.sh` | Import secrets from file to cluster |
| `check-secrets.sh` | Check status of secrets in cluster |

## Required Secrets

### dialtone-secrets (namespace: dialtone-apps)

| Key | Description | How to Get |
|-----|-------------|------------|
| `grok-api-key` | xAI API key | https://console.x.ai |
| `jwt-secret` | JWT signing secret | `openssl rand -base64 32` |
| `x-oauth-client-secret` | Twitter OAuth | https://developer.twitter.com |
| `discord-oauth-client-secret` | Discord OAuth | https://discord.com/developers |
| `resend-api-key` | Email service | https://resend.com |
| `skalholt-sso-secret` | Skalholt SSO | `openssl rand -hex 32` |

### ghcr-secret (namespace: dialtone-apps)

Docker registry credentials for pulling private images from ghcr.io.

- **Username**: Your GitHub username
- **Token**: GitHub PAT with `read:packages` scope

### nginx-tls (namespace: dialtone-apps)

TLS certificate for HTTPS. Generate self-signed:
```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=dialtone.local"
```

### ghcr-helm-credentials (namespace: crossplane-system)

Credentials for Crossplane to pull Helm charts from ghcr.io.

- **Username**: Your GitHub username
- **Password**: GitHub PAT with `read:packages` scope

## Security Notes

- **Never commit `secrets.env` to git** - it's in `.gitignore`
- Store backups encrypted (consider using `gpg` or a password manager)
- Use different credentials for different environments if possible
- Rotate secrets periodically, especially after team member changes

## Transferring to New Cluster

1. On source cluster:
   ```bash
   ./export-secrets.sh secrets-backup.env
   ```

2. Securely transfer `secrets-backup.env` to new machine

3. On target cluster:
   ```bash
   ./import-secrets.sh secrets-backup.env
   ```

4. Delete the backup file:
   ```bash
   shred -u secrets-backup.env  # or just rm
   ```
