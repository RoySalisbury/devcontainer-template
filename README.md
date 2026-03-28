# devcontainer-template

Standard dev container setup for RoySalisbury .NET repos. Works identically in **GitHub Codespaces** and **local devcontainers** (VS Code + Docker Desktop).

## What's Included

| File | Purpose |
|------|---------|
| `.devcontainer/Dockerfile` | `base:ubuntu` image + `NUGET_XMLDOC_MODE` for IntelliSense |
| `.devcontainer/devcontainer.json` | Features, extensions, settings, ports, mounts |
| `.devcontainer/post-create.sh` | Loads shared base script, then repo-specific setup |
| `.devcontainer/export-env.sh` | Export Codespace secrets to `.env` + update gist |
| `.devcontainer/test-base.sh` | Smoke test for the shared base script |

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  devcontainer-base.sh (public gist)                     │
│  ── Shared functions for all repos ──                   │
│  dc_bootstrap_env  — .env from gist / Codespace secrets │
│  dc_setup_dotnet   — fix ownership, display info        │
│  dc_install_cli    — jq, ripgrep                        │
│  dc_setup_docker   — group, socket, version             │
│  dc_setup_ssh      — agent, key restore, load keys      │
│  dc_create_contexts— Docker contexts from env vars      │
│  dc_scan_hosts     — SSH host key scanning              │
└────────────────────────┬────────────────────────────────┘
                         │ curl / gh gist view
┌────────────────────────▼────────────────────────────────┐
│  post-create.sh (per-repo)                              │
│  1. Load base script from gist                          │
│  2. Call shared functions                               │
│  3. Repo-specific: restore, build, tools, certs         │
└─────────────────────────────────────────────────────────┘
```

**Base script gist:** https://gist.github.com/RoySalisbury/bceb71a9120e4d393b68308a03399ca5

## Usage

### New repo (from template)

1. Click **"Use this template"** on GitHub (or `gh repo create --template RoySalisbury/devcontainer-template`)
2. Search for `[CUSTOMIZE]` in the files and adjust:
   - `devcontainer.json` → name, solution path, features, ports, mounts, secrets
   - `post-create.sh` → env gist ID, repo-specific build steps
   - `export-env.sh` → list of env vars to export
3. Open in Codespaces or local devcontainer

### Existing repo (migration)

1. Copy `.devcontainer/` from this repo into yours
2. Replace your existing Dockerfile, devcontainer.json, post-create.sh
3. Adjust `[CUSTOMIZE]` sections
4. Delete old workarounds (Yarn APT cleanup, RC SDK removal, etc.)

## Secrets Strategy (Dual-Path)

Secrets work the same way in both environments — no manual setup needed:

```
Codespace                          Local Devcontainer
┌──────────────────┐               ┌──────────────────┐
│ Codespace Secrets │               │ .env file        │
│ (GitHub Settings) │               │ (auto from gist) │
└───────┬──────────┘               └───────┬──────────┘
        │ injected via remoteEnv           │ fetched by post-create.sh
        ▼                                  ▼
┌──────────────────────────────────────────────────────┐
│              Environment Variables                    │
│  AZURE_DEVOPS_PAT, SSH_PRIVATE_KEY, etc.             │
└──────────────────────────────────────────────────────┘
```

**Setup once:**
1. Set secrets in GitHub → Settings → Codespaces → Secrets
2. Open a Codespace, run `bash .devcontainer/export-env.sh`
3. This creates a `.env` and uploads it to a private gist
4. Local devcontainers auto-fetch `.env` from the gist on startup

## What Changed vs. Old Pattern

| Before | After |
|--------|-------|
| `dotnet:1-10.0` base image | `base:ubuntu` + `dotnet:2` feature |
| Yarn APT source workaround in Dockerfile | Not needed |
| RC/preview SDK cleanup in Dockerfile | Not needed |
| 150+ line duplicated post-create.sh | ~60 lines + shared gist |
| Hardcoded Docker context IPs | Env vars (`MAC_HOST`, etc.) |
| Manual `.env` copy for local dev | Auto-fetch from private gist |
| bash only | zsh default + bash available |

## Testing

```bash
# Verify the shared base script loads and all functions work:
bash .devcontainer/test-base.sh
```

## Repos Using This Pattern

| Repo | Status | Notes |
|------|--------|-------|
| [HgvMate](https://github.com/RoySalisbury/HgvMate) | ✅ Migrated | + node, azure-cli, tailscale |
| [HVO.Enterprise.Telemetry](https://github.com/RoySalisbury/HVO.Enterprise.Telemetry) | 🔲 Pending | + deps.compose.yml, usersecrets mount |
| [HVO.AiCodeReview](https://github.com/RoySalisbury/HVO.AiCodeReview) | 🔲 Pending | + Azure OpenAI secrets |
| [HVO.SDK](https://github.com/RoySalisbury/HVO.SDK) | 🔲 Pending | Simplest migration |
| [HVO.Workspace](https://github.com/RoySalisbury/HVO.Workspace) | 🔲 Pending | Multi-repo, clone-repos.sh |
| [HVO.WebSite](https://github.com/RoySalisbury/HVO.WebSite) | 🔲 Pending | + dotnet-ef, fonts |
| [HVO.RoofController](https://github.com/RoySalisbury/HVO.RoofController) | 🔲 Pending | + GPIO/I2C libs |
| [DevOpsMcp](https://github.com/RoySalisbury/DevOpsMcp) | 🔲 Pending | Currently uses universal:2 |
