#!/bin/bash
set -e
set -o pipefail

echo "Running post-create setup..."

# ─────────────────────────────────────────────────────────────────────
# Load shared devcontainer base script (common to all RoySalisbury repos)
# Gist: https://gist.github.com/RoySalisbury/bceb71a9120e4d393b68308a03399ca5
# Provides: dc_bootstrap_env, dc_setup_dotnet, dc_install_cli,
#           dc_setup_docker, dc_setup_ssh, dc_create_contexts, dc_scan_hosts
# ─────────────────────────────────────────────────────────────────────
BASE_GIST="bceb71a9120e4d393b68308a03399ca5"

_load_base_script() {
	local token="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
	if command -v gh >/dev/null 2>&1 && [ -n "$token" ]; then
		GH_TOKEN="$token" gh gist view "$BASE_GIST" --raw --filename devcontainer-base.sh 2>/dev/null && return 0
	fi
	curl -fsSL "https://gist.githubusercontent.com/RoySalisbury/${BASE_GIST}/raw/devcontainer-base.sh" 2>/dev/null && return 0
	return 1
}

BASE_SCRIPT=$(_load_base_script)
if [ -n "$BASE_SCRIPT" ]; then
	eval "$BASE_SCRIPT"
else
	echo "⚠  Could not load devcontainer-base.sh from gist. Continuing without shared setup."
fi

# ─────────────────────────────────────────────────────────────────────
# Shared setup — calls functions from the base script
# ─────────────────────────────────────────────────────────────────────

# [CUSTOMIZE] Set your private .env gist ID here (or "" to skip)
ENV_GIST=""

if type dc_bootstrap_env >/dev/null 2>&1; then
	dc_bootstrap_env "$ENV_GIST"
	dc_setup_dotnet
	dc_install_cli
	dc_setup_docker
	dc_setup_ssh

	# [CUSTOMIZE] Uncomment to create Docker contexts for remote hosts:
	# dc_create_contexts
	# dc_scan_hosts ${MAC_HOST:-} ${LXC_HOST:-} ${PVE_HOST:-}
else
	echo "⚠  Base script not loaded — running inline fallback..."
	sudo chown -R vscode:vscode /home/vscode/.dotnet || true
	dotnet --info
	sudo apt-get update -y && sudo apt-get install -y jq ripgrep || true
fi

# ─────────────────────────────────────────────────────────────────────
# Repo-specific setup — [CUSTOMIZE] add your steps below
# ─────────────────────────────────────────────────────────────────────

# dotnet restore
# dotnet build --no-restore
# dotnet tool install --global dotnet-ef 2>/dev/null || true
# dotnet dev-certs https --clean && dotnet dev-certs https

echo
echo "Post-create setup completed!"
