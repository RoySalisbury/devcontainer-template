# devcontainer-template

Standard dev container setup for RoySalisbury .NET repos. Works identically in **GitHub Codespaces** and **local devcontainers** (VS Code + Docker Desktop).

## What's Included

| File | Purpose |
|------|---------|
| `.devcontainer/Dockerfile` | `base:ubuntu` image + `NUGET_XMLDOC_MODE` for IntelliSense |
| `.devcontainer/devcontainer.json` | Features, extensions, settings, ports, mounts |
| `.devcontainer/post-create.sh` | Loads shared base script, then repo-specific setup |
| `.devcontainer/post-attach.sh` | Fetches `.env` from gist on each attach (with `.zshrc` fallback) |
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
│  1. Load & eval base script from gist                   │
│  2. Resolve GitHub token (env → gh auth → credential)   │
│  3. Call shared functions                               │
│  4. Repo-specific: restore, build, tools, certs         │
└─────────────────────────────────────────────────────────┘
                         │ on each VS Code attach
┌────────────────────────▼────────────────────────────────┐
│  post-attach.sh (per-repo)                              │
│  1. Install .zshrc hook (one-shot fallback for .env)    │
│  2. Fetch .env from private gist                        │
│  3. Source .env, run SSH/Docker context setup            │
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

## Token Resolution

The VS Code credential helper is **not available** during `postCreateCommand` or `postAttachCommand` on first container build. It only becomes available in an interactive terminal session. This drove a two-phase design:

```
postCreateCommand (post-create.sh)
  └─ Token chain: $GH_TOKEN → $GITHUB_TOKEN → gh auth token → git credential fill
     └─ Used to: load gist, resolve token for dc_bootstrap_env
     └─ GIT_TERMINAL_PROMPT=0 prevents interactive prompt hangs
     └─ || true on each step so failures fall through gracefully

postAttachCommand (post-attach.sh)
  └─ Same token chain — may also fail on first build
  └─ Installs .zshrc one-shot hook as fallback:
     └─ On first interactive terminal open, credential helper IS ready
     └─ Hook fetches .env, sources it, then the source line persists
```

Key details:
- `GIT_TERMINAL_PROMPT=0` is **required** — without it, `git credential fill` hangs waiting for input during non-interactive scripts
- The `.zshrc` hook is **idempotent** — it only adds itself once and the fetch line is a no-op once `.env` exists
- The `set -a` / `source` / `set +a` pattern uses `if/fi; set +a` to ensure auto-export is always disabled even if source fails

## Design Decisions

Decisions made during the migration that automated code reviewers (Copilot) keep flagging. These are **intentional** — do not change them without understanding the tradeoffs.

### 1. Remote gist `eval` is intentional (not vendored)

**What reviewers say:** "fetching a script from a remote gist and executing via `eval` is a supply-chain/RCE risk. Consider vendoring."

**Why we do it anyway:** The entire point of the shared base script is a single source of truth across 8+ repos. Vendoring copies into each repo defeats this purpose and creates drift. The gist is:
- Owned by the same account (RoySalisbury) that owns all the repos
- Public, so anyone can audit it
- Fetched via `gh gist view` (authenticated) with a `curl` fallback (public raw URL)
- Has an inline fallback in every repo if the gist is unreachable

If supply-chain integrity becomes a concern, pin to a specific gist revision SHA and verify a hash before eval.

### 2. `GITHUB_TOKEN` / `GH_TOKEN` removed from `remoteEnv`

These are resolved dynamically by the token resolution chain in post-create.sh. Hardcoding them in `remoteEnv` caused issues where stale or empty values overrode the credential helper.

### 3. `|| true` on `_load_base_script` (but NOT on fallback `apt-get`)

The `_load_base_script` call uses `|| true` because `set -e` would skip the fallback message if the function fails. But the fallback `apt-get install jq ripgrep` does **not** use `|| true` — if jq fails to install, the script should fail fast rather than silently continuing to a `jq` command later.

### 4. `.env` gets `chmod 600`

The `.env` file may contain secrets (PATs, API keys). After writing it, we restrict permissions to owner-only to reduce accidental exposure within the container.

### 5. `dc_scan_hosts` arguments are always quoted

Even though the host variables are unlikely to contain spaces, `"${MAC_HOST:-}"` is used instead of bare `${MAC_HOST:-}` to prevent argument splitting. Empty expansions pass as empty strings rather than being silently dropped.

### 6. `.dotnet/tools` PATH persisted in `.zshrc`

The `dotnet tool install` PATH (`$HOME/.dotnet/tools`) is not on the default PATH in the base:ubuntu image. It's exported in the script AND appended to `.zshrc` so it persists in future terminal sessions.

## Migration Notes

Lessons learned from migrating HgvMate, HVO.SDK, and HVO.Workspace:

1. **Stale `project.assets.json`** — When switching from `dotnet:1-10.0` to `base:ubuntu`, leftover `obj/` directories can cause `dotnet restore` to fail with "file already exists". Fix: `find . -name project.assets.json -delete` before restore.

2. **Yarn APT source** — The `dotnet:1-10.0` image shipped with a broken Yarn APT source list. The `base:ubuntu` image doesn't have this, so the `rm -f yarn.list` workaround can be removed.

3. **Multi-SDK repos** — Use the `dotnet:2` feature with `additionalVersions: "9.0,8.0"` rather than installing SDKs in the Dockerfile.

4. **Codespaces repository permissions** — For monorepo setups (HVO.Workspace), the `codespaces.repositories` block in devcontainer.json grants the Codespace token cross-repo access. This has nothing to do with the shared gist and should be preserved as-is.

5. **GH_PAT vs GITHUB_TOKEN** — In Codespaces, the built-in `GITHUB_TOKEN` cannot merge PRs that modify `.github/workflows/`. HVO.Workspace uses a separate `GH_PAT` secret with `workflow` scope for this.

6. **Review comment patterns** — Every migration PR gets the same Copilot review comments: (a) vendor the gist, (b) quote variables, (c) chmod secrets, (d) handle set -a failures. Items b/c/d are valid and should be applied. Item a is intentional (see above).

## Repos Using This Pattern

| Repo | Status | Notes |
|------|--------|-------|
| [HgvMate](https://github.com/RoySalisbury/HgvMate) | ✅ Migrated | + node, azure-cli, tailscale |
| [HVO.SDK](https://github.com/RoySalisbury/HVO.SDK) | ✅ Migrated | PRs #55, #56, #57 |
| [HVO.Workspace](https://github.com/RoySalisbury/HVO.Workspace) | ✅ Migrated | PR #8 — multi-repo, clone-repos.sh, codespaces permissions |
| [HVO.Enterprise.Telemetry](https://github.com/RoySalisbury/HVO.Enterprise.Telemetry) | 🔲 Deferred | Complex CI, many projects |
| [HVO.AiCodeReview](https://github.com/RoySalisbury/HVO.AiCodeReview) | 🔲 Deferred | Leave as-is for now |
| [HVO.WebSite](https://github.com/RoySalisbury/HVO.WebSite) | 🔲 Deferred | Leave as-is for now |
| [HVO.RoofController](https://github.com/RoySalisbury/HVO.RoofController) | 🔲 Deferred | Leave as-is for now |
| [DevOpsMcp](https://github.com/RoySalisbury/DevOpsMcp) | 🔲 Pending | Currently uses universal:2 |
