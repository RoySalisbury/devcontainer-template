#!/bin/bash
# ─────────────────────────────────────────────────────────────────────
# Test that the devcontainer-base.sh gist loads and all functions exist.
# Run manually: bash .devcontainer/test-base.sh
# ─────────────────────────────────────────────────────────────────────
set -e

PASS=0
FAIL=0

check() {
	local desc="$1"
	if eval "$2" >/dev/null 2>&1; then
		echo "  ✅ $desc"
		PASS=$((PASS + 1))
	else
		echo "  ❌ $desc"
		FAIL=$((FAIL + 1))
	fi
}

echo "=== devcontainer-base.sh Smoke Tests ==="
echo ""

# Load the base script
BASE_GIST="bceb71a9120e4d393b68308a03399ca5"
echo "Loading base script from gist ${BASE_GIST}..."
BASE_SCRIPT=$(curl -fsSL "https://gist.githubusercontent.com/RoySalisbury/${BASE_GIST}/raw/devcontainer-base.sh" 2>/dev/null) || true

if [ -z "$BASE_SCRIPT" ]; then
	echo "❌ FATAL: Could not fetch base script from gist"
	exit 1
fi

eval "$BASE_SCRIPT"
echo ""

echo "Checking exported functions..."
check "dc_bootstrap_env exists"  "type dc_bootstrap_env"
check "dc_setup_dotnet exists"   "type dc_setup_dotnet"
check "dc_install_cli exists"    "type dc_install_cli"
check "dc_setup_docker exists"   "type dc_setup_docker"
check "dc_setup_ssh exists"      "type dc_setup_ssh"
check "dc_create_context exists" "type dc_create_context"
check "dc_create_contexts exists" "type dc_create_contexts"
check "dc_scan_hosts exists"     "type dc_scan_hosts"
check "dc_run_all exists"        "type dc_run_all"
check "command_exists exists"    "type command_exists"
echo ""

echo "Checking version..."
check "_DC_BASE_VERSION is set"  '[ -n "$_DC_BASE_VERSION" ]'
echo "  Version: ${_DC_BASE_VERSION:-UNKNOWN}"
echo ""

echo "Checking prerequisites..."
check "dotnet is on PATH"        "command -v dotnet"
check "gh is on PATH"            "command -v gh"
check "docker is on PATH"        "command -v docker"
check "jq is on PATH"            "command -v jq"
check "curl is on PATH"          "command -v curl"
echo ""

echo "Running dc_setup_dotnet..."
dc_setup_dotnet 2>&1 | head -5
echo "  (truncated)"
echo ""

echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
