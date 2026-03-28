#!/bin/bash
# ─────────────────────────────────────────────────────────────────────
# Export Codespace secrets to .env and (optionally) update a private gist.
#
# Usage (run inside a Codespace):
#   bash .devcontainer/export-env.sh
#
# This generates .env from the Codespace secrets that your repo uses.
# The .env is gitignored and auto-fetched by post-create.sh on local
# devcontainers, so both environments behave identically.
# ─────────────────────────────────────────────────────────────────────
set -euo pipefail

WORKSPACE="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${WORKSPACE}/.env"

# [CUSTOMIZE] Your private gist ID (empty = skip gist update)
ENV_GIST=""

if [ -z "${CODESPACES:-}" ]; then
	echo "⚠  This does not appear to be a GitHub Codespace."
	read -r -p "Continue anyway? [y/N] " confirm
	[[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }
fi

# ─── [CUSTOMIZE] List the env vars your repo needs ───────────────
cat > "$ENV_FILE" <<EOF
# Auto-generated from Codespace secrets — $(date -u +%Y-%m-%dT%H:%M:%SZ)
# AZURE_DEVOPS_PAT=${AZURE_DEVOPS_PAT:-}
# MY_OTHER_SECRET=${MY_OTHER_SECRET:-}
EOF

# SSH key: escape newlines for single-line .env storage
if [ -n "${SSH_PRIVATE_KEY:-}" ]; then
	KEY_ESCAPED=$(echo "$SSH_PRIVATE_KEY" | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
	echo "SSH_PRIVATE_KEY=$KEY_ESCAPED" >> "$ENV_FILE"
elif [ -f /home/vscode/.ssh/id_ed25519 ]; then
	KEY_ESCAPED=$(awk '{printf "%s\\n", $0}' /home/vscode/.ssh/id_ed25519 | sed 's/\\n$//')
	echo "SSH_PRIVATE_KEY=$KEY_ESCAPED" >> "$ENV_FILE"
fi

chmod 600 "$ENV_FILE"
echo "✅ Generated $ENV_FILE"

# Update gist so local devcontainers auto-fetch the latest secrets
if [ -n "$ENV_GIST" ]; then
	GH_TOKEN="${GITHUB_TOKEN}" gh gist edit "$ENV_GIST" "$ENV_FILE" 2>/dev/null \
		&& echo "✅ Gist updated." \
		|| echo "⚠  Could not update gist (check permissions)."
fi
