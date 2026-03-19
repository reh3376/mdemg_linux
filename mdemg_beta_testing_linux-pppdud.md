# MDEMG Linux Beta Testing Guide

**Version under test:** v0.2.15 (CLI) / v0.2.0 (Sidebar)

**Date:** March 19th, 2026

**Tester:** PPPDUD

**Machine specs:** amd64 32-thread with NVIDIA 5060TI GPU

**Distro:** Ubuntu 25.10 (output of `cat /etc/os-release | grep PRETTY_NAME`)

**Kernel:** 6.17.0-19-generic (output of `uname -r`)

**Docker Engine version:** 29.1.3

**Desktop Environment:** GNOME (GNOME / KDE / XFCE / None)

---

## What is MDEMG?

MDEMG (Multi-Dimensional Emergent Memory Graph) is a **persistent memory system for AI coding assistants** like Claude Code, Cursor, and GitHub Copilot. Think of it as a "long-term brain" — without MDEMG, these AI tools forget everything between sessions. With MDEMG, they remember your codebase, your decisions, your corrections, and your preferences across every conversation.

### How It Works (The 60-Second Version)

1. **You code with an AI assistant** — MDEMG runs quietly in the background
2. **Observations are captured** — decisions you make, corrections you give, patterns in your code
3. **A knowledge graph grows** — Neo4j stores these observations with semantic connections between them
4. **Higher-level concepts emerge** — MDEMG automatically identifies themes, clusters similar knowledge, and strengthens frequently co-activated connections (Hebbian learning, like neurons in a brain)
5. **Your AI assistant gets smarter** — next session, it recalls relevant past context instead of starting from scratch

### Key Concepts You'll Encounter During Testing

| Concept | What It Means |
|---------|---------------|
| **Space** | An isolated knowledge graph. Each project gets its own space (like a separate brain for each codebase). |
| **Observation** | A unit of knowledge — a decision, correction, error, preference, or learning captured from a session. |
| **CMS** (Conversation Memory System) | The subsystem that captures, stores, and retrieves observations from AI sessions. |
| **RSIC** (Reflective Self-Improvement Cycle) | An automated loop that periodically analyzes the knowledge graph, identifies gaps, and optimizes retrieval quality. |
| **Consolidation** | The process of clustering similar observations and creating higher-level "concept" nodes (like how the brain moves short-term memories into long-term storage during sleep). |
| **Hebbian Learning** | "Neurons that fire together wire together" — observations accessed together get linked, strengthening the graph over time. |
| **Jiminy** | An inner-voice guidance system that proactively surfaces relevant past context, warnings, and suggestions during AI sessions. |
| **Ingest** | Feeding data into MDEMG — code files, git history, API docs, etc. |
| **Recall** | Querying MDEMG to retrieve relevant past knowledge using semantic search. |
| **MCP** (Model Context Protocol) | A standard for AI tools to communicate with external systems. MDEMG runs as an MCP server so any MCP-compatible AI assistant can use it. |

### What You're Testing

This guide walks you through installing and exercising every major MDEMG subsystem on Linux:

- **Tier 1**: Installation, Neo4j database, server startup, health checks
- **Tier 2**: Feeding data into the system (8 ingestion methods)
- **Tier 3**: Memory capture, recall, self-improvement cycles
- **Tier 4**: Backup, maintenance, edge decay
- **Tier 5**: Advanced features (secrets, MCP, systemd, export/import)
- **Sidebar App**: A desktop companion that monitors MDEMG health, shows memory stats, and manages server lifecycle via system tray

You do NOT need to be an expert. The tests are designed as step-by-step commands with expected outputs. If something doesn't match, that's valuable feedback — file an issue (see [Feedback & Contributing](#feedback--contributing) at the bottom).

---

## Results Summary

| Tier | Section | Tests | Pass | Fail | Skip | Notes |
|------|---------|-------|------|------|------|-------|
| 1 | Installation & Core | 9 | | | | |
| 2 | Ingestion | 8 | | | | |
| 3 | CMS & RSIC | 10 | | | | |
| 4 | Backup & Maintenance | 5 | | | | |
| 5 | Advanced | 11 | | | | |
| S | Sidebar App | 5 | | | | |
| **Total** | | **48** | | | | |

---

## Prerequisites

Complete each section below in order before starting the tests. Do not assume anything is pre-installed — verify each item.

### Step 1: Verify Linux Distribution

MDEMG supports Linux on amd64 and arm64 architectures. Tested distributions: Ubuntu 20.04+, Debian 11+, Fedora 38+, RHEL/CentOS 8+, Arch Linux.

```bash
# Check your distro and version
cat /etc/os-release

# Check kernel version
uname -r

# Check architecture
uname -m
# Must be x86_64 (amd64) or aarch64 (arm64)
```

- [ ] Linux distro and version verified: _______________
- [ ] Architecture verified: _______________

### Step 2: Install Required Tools

Ensure `curl` (or `wget`), `tar`, and `jq` are installed.

```bash
# Check required tools
curl --version
tar --version
jq --version

# If missing, install for your distro:

# Debian/Ubuntu:
sudo apt update && sudo apt install -y curl tar jq

# Fedora/RHEL/CentOS:
sudo dnf install -y curl tar jq

# Arch:
sudo pacman -S curl tar jq
```

- [ ] Required tools installed

### Step 3: Install Docker Engine

Docker Engine runs the Neo4j database container. MDEMG cannot function without it.

```bash
# Check if Docker is already installed and running
docker --version
docker info   # This must succeed — if it errors, Docker Engine is not running

# Install Docker Engine — follow the official guide for your distro:
# https://docs.docker.com/engine/install/

# Debian/Ubuntu quick install:
curl -fsSL https://get.docker.com | sudo sh

# Add your user to the docker group (avoids needing sudo for every command):
sudo usermod -aG docker $USER
# Log out and back in for the group change to take effect
```

After installation:

```bash
# Start Docker Engine
sudo systemctl start docker
sudo systemctl enable docker

# Verify Docker is running
docker info
# Should show "Server: Docker Engine"

docker run --rm hello-world
# Should print "Hello from Docker!"
```

> **Note:** Docker Engine must be running whenever you use MDEMG. Enable it at boot with `sudo systemctl enable docker`. Unlike Docker Desktop on macOS, Docker Engine on Linux has no default memory cap — it uses available system memory.

- [ ] Docker Engine installed and running, version: _______________

### Step 4: Internet Access

The machine must have internet access to:
- Download the MDEMG binary via the installer or package manager
- Pull the Neo4j Docker image (`neo4j:5`, ~500MB) on first `mdemg db start`
- (Optional) Connect to the OpenAI API for embeddings

```bash
# Verify connectivity to GitHub
curl -s https://api.github.com/repos/reh3376/mdemg/releases/latest | grep tag_name
```

- [ ] Internet access confirmed

### Optional Prerequisites

These are not required for basic testing but are needed for specific test tiers.

#### OpenAI API Key (Tier 2-3: recall, consolidation, memory retrieval)

Required for embedding-powered features: semantic recall, consolidation concept naming, memory retrieval, and SME consulting. Without a key, these features run in degraded mode (stub embeddings or no results).

1. Sign up at [platform.openai.com](https://platform.openai.com)
2. Create an API key at [platform.openai.com/api-keys](https://platform.openai.com/api-keys)
3. Save the key — you'll configure it during `mdemg init` or set it in a `.env` file

- [ ] OpenAI API key obtained (or will skip embedding tests)

#### Ollama (Alternative to OpenAI)

Local-only alternative to OpenAI for embeddings. No API key or internet required after initial download.

```bash
# Install via official script
curl -fsSL https://ollama.com/install.sh | sh

# Pull an embedding model
ollama pull nomic-embed-text

# Verify
ollama list
```

> **Dimension warning:** OpenAI `text-embedding-3-large` produces 3072-dimension embeddings. Many Ollama models produce fewer dimensions. Run `mdemg embeddings check` after setup to verify. If dimensions don't match the existing vector index, you may need to recreate it.

- [ ] Ollama installed (or using OpenAI, or will skip embedding tests)

#### Git (Tier 2: hooks, incremental ingest, test project setup)

Required for git hooks, incremental ingest (`--since`), and setting up the test project. Most Linux systems have Git pre-installed.

```bash
# Check if Git is already installed
git --version

# If missing, install:
# Debian/Ubuntu:
sudo apt install -y git

# Fedora/RHEL:
sudo dnf install -y git

# Arch:
sudo pacman -S git
```

- [ ] Git installed, version: _______________
- [ ] **SKIP** — will skip git-dependent tests (T2.4, T2.5)

### Set Up Test Project

> **Requires:** Git (from optional prerequisites above). If Git is not installed, you can still test most features — just create the test directory and file manually without the git commands.

**With Git installed:**

```bash
mkdir -p ~/mdemg-test && cd ~/mdemg-test
git init
git config user.email "tester@example.com"
git config user.name "Beta Tester"

# Create a sample file for ingestion tests
cat > main.go << 'EOF'
package main

import "fmt"

func main() {
    fmt.Println("Hello from MDEMG beta test")
}
EOF

git add . && git commit -m "initial commit"
```

**Without Git (manual alternative):**

```bash
mkdir -p ~/mdemg-test && cd ~/mdemg-test
cat > main.go << 'EOF'
package main

import "fmt"

func main() {
    fmt.Println("Hello from MDEMG beta test")
}
EOF
```

> **Note:** Without Git, you will need to skip tests T2.4 (incremental ingest), T2.5 (hooks), and T1.3's init may not detect a git repo.

- [ ] Test project directory created at `~/mdemg-test`

### Prerequisites Checklist Summary

| # | Requirement | Status | Comments |
|---|-------------|--------|----------|
| 1 | Linux (amd64 or arm64) | | Supported distros: Ubuntu 20.04+, Debian 11+, Fedora 38+, RHEL 8+, Arch. Verify: `cat /etc/os-release` |
| 2 | curl, tar, jq installed | | Required for installation and testing. Verify: `curl --version && tar --version && jq --version` |
| 3 | Docker Engine installed and running | | Neo4j runs as a Docker container. Verify: `docker info` succeeds without errors |
| 4 | Internet access confirmed | | Needed to download binary and Docker images. Verify: `curl -s https://github.com` returns HTML |
| — | *OpenAI API key (optional)* | | Enables LLM summaries, recall re-ranking, consolidation naming. Without it, those features return degraded results. Verify: `echo $OPENAI_API_KEY` is set |
| — | *Ollama (optional)* | | Local LLM alternative to OpenAI — no API key needed. Verify: `ollama list` shows available models |
| — | *Git (optional)* | | Required for incremental ingest, git hooks, and commit-triggered ingestion. Verify: `git --version` |
| — | Test project created | | Isolated directory for beta testing. Verify: `test -d ~/mdemg-test && echo OK` |

---

## Reference Documentation

These docs cover everything you're testing. Use them for troubleshooting, understanding expected behavior, or exploring beyond the test plan.

| Guide | What it covers |
|-------|---------------|
| [README](README.md) | Quick start, commands overview, configuration, troubleshooting |
| [CLI Reference](docs/cli-reference.md) | All commands, flags, defaults, examples, environment variables |
| [API Reference](docs/api-reference.md) | Every HTTP endpoint with request/response shapes and curl examples |
| [CMS & RSIC Guide](docs/cms-rsic-guide.md) | Conversation memory, Jiminy inner-voice guidance, observation types, self-improvement cycles |
| [Ingestion Guide](docs/ingestion-guide.md) | All 8 ingestion methods — codebase, scraper, Linear, webhooks, file watcher, API |
| [Sidebar README](https://github.com/reh3376/mdemg-linux-sidebar/blob/main/README.md) | Sidebar app installation, architecture, system tray compatibility, multi-instance |

---

## Tier 1: Installation & Core (~30 min)

### T1.1: Installation

Choose one of the available installation methods:

**Method A — curl installer (recommended):**

```bash
curl -fsSL https://raw.githubusercontent.com/reh3376/mdemg_linux/main/install.sh | bash
```

**Method B — manual tarball:**

```bash
# Download the latest tarball for your architecture
ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
VERSION=$(curl -fsSL https://api.github.com/repos/reh3376/mdemg/releases/latest | grep tag_name | sed -E 's/.*"([^"]+)".*/\1/')
curl -fsSL -o /tmp/mdemg.tar.gz \
  "https://github.com/reh3376/mdemg/releases/download/${VERSION}/mdemg_${VERSION#v}_linux_${ARCH}.tar.gz"

# Extract and install manually
tar -xzf /tmp/mdemg.tar.gz -C /tmp/mdemg-extract
sudo install -m 755 /tmp/mdemg-extract/mdemg /usr/local/bin/mdemg
```

> **Note:** .deb and .rpm packages are planned for a future release but are not yet available.

**Expected:** The `mdemg` binary is installed to `/usr/local/bin/mdemg`. No errors.

```bash
# Verify binary is on PATH
which mdemg
```

If `mdemg: command not found`, verify `/usr/local/bin` is in your PATH:

```bash
# Check that /usr/local/bin is on PATH
echo $PATH | tr ':' '\n' | grep '/usr/local/bin'

# If missing, add it:
echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

- [ ] **PASS** — installation completed, `mdemg` accessible from terminal
- [ ] **Method used:** (A) curl installer / (B) manual tarball

---

### T1.2: Verify Binary

```bash
mdemg version
```

**Expected output:**

```
mdemg v0.2.15
  commit:  <short-hash>
  built:   <date>
  go:      go1.24.x
  os/arch: linux/amd64    # or linux/arm64
```

- [ ] **PASS** — version displayed with `linux/amd64` or `linux/arm64`

---

### T1.3: Initialize Project

```bash
cd ~/mdemg-test
mdemg init
```

**Expected:** Interactive wizard prompts for Space ID, Neo4j URI, embedding provider, and OpenAI API key. Creates `.mdemg/config.yaml`, `.mdemgignore`, and `.env` in the current directory.

> **Important:** Do NOT use `--defaults` here. The interactive wizard lets you enter your OpenAI API key, which is required for embedding and LLM features in subsequent tests. If you skip this, `mdemg start` will fail on embedding checks.

```bash
# Verify files exist
ls -la .mdemg/config.yaml .mdemgignore
```

- [ ] **PASS** — both files exist and contain valid content

---

### T1.4: Neo4j Container Lifecycle

```bash
# Start Neo4j
mdemg db start

# Check status
mdemg db status

# Stop Neo4j
mdemg db stop

# Restart Neo4j
mdemg db start
```

**Expected:** Each command succeeds. `mdemg db status` shows the container as `running` with port info.

```bash
# Verify container is running
docker ps --filter "name=mdemg-neo4j" --format "{{.Status}}"
```

- [ ] **PASS** — container starts, status shows running, stops cleanly, restarts

---

### T1.5: Database Migrations

```bash
mdemg db migrate
```

**Expected:** Migrations apply without errors. Output shows "applied N migrations" or "already up to date."

- [ ] **PASS** — migrations complete successfully

---

### T1.6: Server Start

**Try daemon mode first:**

```bash
mdemg start --auto-migrate
```

**Expected:** Server starts as a background daemon on port 9999.

```bash
# Verify
mdemg status
```

**Fallback — foreground mode (open a second terminal):**

```bash
mdemg serve --auto-migrate
```

Leave this terminal running. Continue tests in the original terminal.

**Record which method worked:**

- [ ] **PASS (daemon)** — `mdemg start` worked
- [ ] **PASS (foreground)** — `mdemg serve` worked (daemon failed)
- [ ] **FAIL** — neither method started the server

---

### T1.7: Health Checks

```bash
# Health check
curl -s http://localhost:9999/healthz

# Readiness check
curl -s http://localhost:9999/readyz
```

**Expected:** Both return `{"status":"ok"}` (or similar JSON with healthy status).

- [ ] **PASS** — both endpoints respond with OK status

---

### T1.8: Configuration Display & Validation

```bash
mdemg config show
mdemg config validate
```

**Expected:** `config show` displays effective configuration with source annotations (yaml/env/default). `config validate` probes Neo4j connectivity and reports results.

- [ ] **PASS** — config show displays settings, validate confirms Neo4j reachable

---

### T1.9: Embedding Provider Check

```bash
mdemg embeddings check
```

**Expected (with OpenAI key configured):** Reports embedding provider, model, and dimension count (3072 for text-embedding-3-large).

**Expected (without key):** Reports "no embedding provider configured" or similar warning. This is acceptable — skip to Tier 2.

- [ ] **PASS** — embedding check runs and reports status
- [ ] **SKIP** — no embedding provider configured (note in results)

---

## Tier 2: Ingestion (~20 min)

> **Reference:** [Ingestion Guide](docs/ingestion-guide.md) covers all 8 ingestion methods in detail. [API Reference](docs/api-reference.md#codebase-ingestion-api) has full endpoint documentation.

### T2.1: Codebase Ingestion (CLI)

```bash
mdemg ingest --path . --space-id beta-test
```

**Expected:** Ingests files from the test project. Output shows files processed, observations created.

- [ ] **PASS** — ingest completes, shows file count and observations

---

### T2.2: Single Observation (API)

```bash
curl -s -X POST http://localhost:9999/v1/conversation/observe \
  -H "Content-Type: application/json" \
  -d '{
    "space_id": "beta-test",
    "session_id": "beta-session",
    "content": "This is a test observation from Linux beta testing",
    "obs_type": "learning"
  }'
```

**Expected:** Returns JSON with `node_id` and `status` fields.

- [ ] **PASS** — observation created, node_id returned

---

### T2.3: Batch Ingest (API)

```bash
curl -s -X POST http://localhost:9999/v1/memory/ingest \
  -H "Content-Type: application/json" \
  -d '{
    "space_id": "beta-test",
    "nodes": [
      {"content": "Linux batch test item 1", "metadata": {"source": "beta-test"}},
      {"content": "Linux batch test item 2", "metadata": {"source": "beta-test"}}
    ]
  }'
```

**Expected:** Returns JSON with count of ingested nodes.

- [ ] **PASS** — batch ingest returns success with node count

---

### T2.4: Incremental Ingest

```bash
# Modify test file
echo "// Updated for incremental test" >> main.go
git add . && git commit -m "incremental test change"

# Incremental ingest
mdemg ingest --path . --space-id beta-test --incremental --since HEAD~1
```

**Expected:** Only the modified file is re-ingested.

- [ ] **PASS** — incremental ingest processes only changed files

---

### T2.5: Git Hooks

```bash
# Install hooks
mdemg hooks install --space-id beta-test

# Verify
mdemg hooks list

# Make a commit — hook should trigger auto-ingest
echo "// Hook trigger test" >> main.go
git add . && git commit -m "hook test"
```

**Expected:** `hooks list` shows post-commit hook installed. After commit, hook triggers background ingest (check server logs for ingest activity).

- [ ] **PASS** — hooks install, list shows installed, commit triggers ingest
- [ ] **SKIP** — Git not installed

---

### T2.6: File Watcher

Open a **second terminal:**

```bash
cd ~/mdemg-test
mdemg watch --path . --space-id beta-test
```

In the **original terminal**, create a new file:

```bash
echo "// New file for watcher test" > watcher_test.go
```

**Expected:** The watcher terminal shows the new file was detected and ingested.

Press `Ctrl+C` in the watcher terminal when done.

- [ ] **PASS** — watcher detects file creation and ingests it

---

### T2.7: Web Scraper

> **Skip** if no target URL is available for scraping.

```bash
curl -s -X POST http://localhost:9999/v1/scraper/jobs \
  -H "Content-Type: application/json" \
  -d '{
    "space_id": "beta-test",
    "url": "https://example.com",
    "max_pages": 1
  }'
```

**Expected:** Returns a job ID. Check status with `GET /v1/scraper/jobs/{job_id}`.

- [ ] **PASS** — scraper job created
- [ ] **SKIP** — no URL configured

---

### T2.8: Linear Integration

> **Skip** if no `LINEAR_API_KEY` is configured.

```bash
curl -s http://localhost:9999/v1/linear/issues?space_id=beta-test
```

**Expected:** Returns issues list or empty array.

- [ ] **PASS** — Linear endpoint responds
- [ ] **SKIP** — no LINEAR_API_KEY configured

---

## Tier 3: CMS & RSIC (~20 min)

> **Reference:** [CMS & RSIC Guide](docs/cms-rsic-guide.md) explains the full CMS workflow, RSIC pipeline, Jiminy inner-voice guidance, and includes practical examples. [API Reference](docs/api-reference.md#conversation-memory) has all endpoint shapes.

### T3.1: Observe (Multiple Types)

```bash
# Decision observation
curl -s -X POST http://localhost:9999/v1/conversation/observe \
  -H "Content-Type: application/json" \
  -d '{
    "space_id": "beta-test",
    "session_id": "beta-session",
    "content": "Decided to use the curl installer for all Linux installations",
    "obs_type": "decision"
  }'

# Error observation
curl -s -X POST http://localhost:9999/v1/conversation/observe \
  -H "Content-Type: application/json" \
  -d '{
    "space_id": "beta-test",
    "session_id": "beta-session",
    "content": "Build failed: missing dependency xyz",
    "obs_type": "error"
  }'
```

**Expected:** Both return JSON with `node_id`.

- [ ] **PASS** — multiple obs_types accepted (decision, error)

---

### T3.2: Resume Session

```bash
curl -s -X POST http://localhost:9999/v1/conversation/resume \
  -H "Content-Type: application/json" \
  -d '{
    "space_id": "beta-test",
    "session_id": "beta-session",
    "max_observations": 10
  }'
```

**Expected:** Returns previously observed content from the session.

- [ ] **PASS** — resume returns prior observations

---

### T3.3: Recall (Semantic Query)

> **Requires:** Embedding provider configured (OpenAI or Ollama)

```bash
curl -s -X POST http://localhost:9999/v1/conversation/recall \
  -H "Content-Type: application/json" \
  -d '{
    "space_id": "beta-test",
    "query": "What decisions were made during testing?",
    "top_k": 5
  }'
```

**Expected:** Returns relevant observations ranked by semantic similarity.

- [ ] **PASS** — recall returns relevant results
- [ ] **SKIP** — no embedding provider (degraded mode)

---

### T3.4: Correct

```bash
curl -s -X POST http://localhost:9999/v1/conversation/correct \
  -H "Content-Type: application/json" \
  -d '{
    "space_id": "beta-test",
    "session_id": "beta-session",
    "content": "Correction: dependency xyz is actually version 2.0",
    "obs_type": "correction"
  }'
```

**Expected:** Returns JSON confirming the correction was recorded.

- [ ] **PASS** — correction accepted and stored

---

### T3.5: Consolidation

```bash
curl -s -X POST http://localhost:9999/v1/memory/consolidate \
  -H "Content-Type: application/json" \
  -d '{"space_id": "beta-test"}'
```

**Expected:** Returns consolidation results (hidden nodes created, edges formed). Without an LLM key, concept naming may be degraded but consolidation still runs.

- [ ] **PASS** — consolidation completes

---

### T3.6: Session Health

```bash
curl -s "http://localhost:9999/v1/conversation/session/health?space_id=beta-test&session_id=beta-session"
```

**Expected:** Returns health metrics for the session (observation count, freshness, etc.).

- [ ] **PASS** — session health returned with metrics

---

### T3.7: RSIC Assess

```bash
curl -s -X POST http://localhost:9999/v1/self-improve/assess \
  -H "Content-Type: application/json" \
  -d '{"space_id": "beta-test"}'
```

**Expected:** Returns assessment with scores and recommendations.

- [ ] **PASS** — assessment returned

---

### T3.8: RSIC Cycle (Dry Run)

```bash
curl -s -X POST http://localhost:9999/v1/self-improve/cycle \
  -H "Content-Type: application/json" \
  -d '{"space_id": "beta-test", "dry_run": true}'
```

**Expected:** Returns what the self-improvement cycle *would* do, without making changes.

- [ ] **PASS** — dry run cycle returns plan

---

### T3.9: RSIC Health

```bash
curl -s "http://localhost:9999/v1/self-improve/health?space_id=beta-test"
```

**Expected:** Returns RSIC health metrics.

- [ ] **PASS** — RSIC health returned

---

### T3.10: Learning Freeze / Unfreeze

```bash
# Freeze
curl -s -X POST http://localhost:9999/v1/learning/freeze \
  -H "Content-Type: application/json" \
  -d '{"space_id": "beta-test", "reason": "beta testing", "frozen_by": "tester"}'

# Check status
curl -s "http://localhost:9999/v1/learning/status?space_id=beta-test"

# Unfreeze
curl -s -X POST http://localhost:9999/v1/learning/unfreeze \
  -H "Content-Type: application/json" \
  -d '{"space_id": "beta-test"}'
```

**Expected:** Freeze returns confirmation, status shows frozen=true, unfreeze returns confirmation.

- [ ] **PASS** — freeze/status/unfreeze cycle completes

---

## Tier 4: Backup & Maintenance (~10 min)

### T4.1: Backup Trigger

```bash
curl -s -X POST http://localhost:9999/v1/backup/trigger \
  -H "Content-Type: application/json" \
  -d '{"space_id": "beta-test"}'
```

**Expected:** Returns backup job ID or confirmation.

- [ ] **PASS** — backup triggered

---

### T4.2: Backup List

```bash
curl -s "http://localhost:9999/v1/backup/list?space_id=beta-test"
```

**Expected:** Returns list of backups (may include the one just created).

- [ ] **PASS** — backup list returned

---

### T4.3: Decay (Dry Run)

```bash
mdemg decay --space-id beta-test --dry-run
```

**Expected:** Shows what edges would be decayed without making changes.

- [ ] **PASS** — decay dry run shows results

---

### T4.4: Prune (Dry Run)

```bash
mdemg prune --space-id beta-test --dry-run
```

**Expected:** Shows what edges/nodes would be pruned without making changes.

- [ ] **PASS** — prune dry run shows results

---

### T4.5: Space List

```bash
mdemg space list
```

**Expected:** Lists all spaces including `beta-test`.

- [ ] **PASS** — space list shows beta-test

---

## Tier 5: Advanced (~15 min)

> **Reference:** [CLI Reference](docs/cli-reference.md) has full flag details for every command. [API Reference](docs/api-reference.md#mcp-server-tools) covers MCP server tools.

### T5.1: Secrets (Linux Keyring)

> **Note:** On Linux, `mdemg config set-secret` uses the system keyring backend. The backend depends on your desktop environment:
> - **GNOME:** gnome-keyring (usually pre-installed)
> - **KDE:** kwallet
> - **Headless/SSH:** `pass` (password-store) with GPG
>
> **Headless servers:** Keyring operations require a D-Bus session bus. If running over SSH or on a headless server without a desktop environment, you must set up a keyring backend manually:
>
> ```bash
> # Option 1: Install and configure pass (GPG-based, no desktop required)
> sudo apt install pass gnupg2   # Debian/Ubuntu
> sudo dnf install pass gnupg2   # Fedora/RHEL
> gpg --gen-key                  # Generate a GPG key if you don't have one
> pass init <your-gpg-key-id>
>
> # Option 2: Start a D-Bus session for gnome-keyring
> eval $(dbus-launch --sh-syntax)
> export DBUS_SESSION_BUS_ADDRESS
> ```
>
> If no keyring backend is available, `set-secret` will fail with an error. Fall back to setting secrets in `.env` instead.

```bash
# Store a test secret
mdemg config set-secret TEST_BETA_KEY "beta-test-value-12345"

# Retrieve it
mdemg config get-secret TEST_BETA_KEY

# List all secrets
mdemg config list-secrets
```

**Expected:** Secret is stored in the Linux system keyring (gnome-keyring, kwallet, or pass), retrieved correctly, and listed.

- [ ] **PASS** — set/get/list secrets works via Linux keyring
- [ ] **SKIP** — headless server, no keyring backend available (used .env fallback)

---

### T5.2: Memory Retrieval

```bash
curl -s -X POST http://localhost:9999/v1/memory/retrieve \
  -H "Content-Type: application/json" \
  -d '{
    "space_id": "beta-test",
    "query": "beta testing",
    "top_k": 5
  }'
```

**Expected:** Returns retrieved memory nodes.

- [ ] **PASS** — memory retrieval returns results
- [ ] **SKIP** — no embedding provider

---

### T5.3: Demo

```bash
mdemg demo
```

**Expected:** Interactive demo runs, shows MDEMG capabilities. Follow on-screen prompts.

- [ ] **PASS** — demo runs to completion

---

### T5.4: Extract Symbols

```bash
mdemg extract-symbols --path .
```

**Expected:** Extracts code symbols (functions, types, etc.) from files in the directory.

- [ ] **PASS** — symbols extracted and listed

---

### T5.5: Consolidation (CLI)

```bash
mdemg consolidate --space-id beta-test --dry-run
```

**Expected:** Shows consolidation plan without executing.

- [ ] **PASS** — consolidation dry run shows plan

---

### T5.6: MCP Server

```bash
mdemg mcp
```

**Expected:** MCP server starts and listens for JSON-RPC input on stdin. Press `Ctrl+C` to exit.

- [ ] **PASS** — MCP server starts, responds to Ctrl+C

---

### T5.7: Upgrade Check

```bash
mdemg upgrade --dry-run
```

**Expected:** Reports current version and latest available version.

- [ ] **PASS** — upgrade check runs and reports version information
- [ ] **FAIL** — upgrade fails (note error message below)

**Error message received (if failed):** _______________

---

### T5.8: Space Export/Import (API)

```bash
# Preview what would be exported
curl -s "http://localhost:9999/v1/admin/spaces/export/preview?space_id=beta-test&profile=full"

# Export the space
curl -s -X POST http://localhost:9999/v1/admin/spaces/export \
  -H "Content-Type: application/json" \
  -d '{"space_id":"beta-test","profile":"metadata"}' > /tmp/beta-export.json

# Verify export has chunks
cat /tmp/beta-export.json | jq '.summary'

# Import to a new space (empty chunks for validation)
curl -s -X POST http://localhost:9999/v1/admin/spaces/import \
  -H "Content-Type: application/json" \
  -d '{"space_id":"beta-test-import","conflict":"skip","chunks":[]}'
```

**Expected:**
- Preview returns `estimated_nodes`, `profile`, and `filters_applied`
- Export returns JSON with `header.format: "mdemg-space-transfer"`, `chunks` array, and `summary`
- Import returns `nodes_created: 0` (empty chunks), `warnings: []`

```bash
# CLI export/import (alternative)
mdemg space export --space-id beta-test --output /tmp/beta-test.mdemg --profile metadata
mdemg space import --input /tmp/beta-test.mdemg --target-space beta-test-cli-import
```

- [ ] **PASS** — API export preview returns valid JSON with estimated counts
- [ ] **PASS** — API export returns chunks with `mdemg-space-transfer` format
- [ ] **PASS** — API import accepts empty chunks and returns 200
- [ ] **PASS** — CLI export creates `.mdemg` file
- [ ] **PASS** — CLI import succeeds with target space

---

### T5.9: Systemd Service

> **Requires:** systemd (standard on most modern Linux distributions). Skip this section if running on a non-systemd init system (e.g., Alpine with OpenRC).

**Install the service units** (if not already installed by the installer):

```bash
# Check if service files were installed
ls /etc/systemd/system/mdemg@.service

# If missing, install manually from the repo:
sudo cp /usr/local/share/mdemg/systemd/mdemg.service /etc/systemd/system/mdemg@.service
sudo cp /usr/local/share/mdemg/systemd/mdemg-rsic.service /etc/systemd/system/mdemg-rsic@.service
sudo cp /usr/local/share/mdemg/systemd/mdemg-rsic.timer /etc/systemd/system/mdemg-rsic@.timer
sudo systemctl daemon-reload
```

**Test the main MDEMG service:**

```bash
# Stop any running mdemg instance first
mdemg stop 2>/dev/null || true

# Enable and start the service (parameterized by user)
sudo systemctl enable --now mdemg@$USER

# Check status
systemctl status mdemg@$USER

# Verify the server is responding
curl -s http://localhost:9999/healthz

# View logs
journalctl -u mdemg@$USER --no-pager -n 20
```

**Expected:** Service starts, `systemctl status` shows `active (running)`, health check returns OK, logs show server startup messages.

**Test the RSIC timer:**

```bash
# Enable the RSIC timer
sudo systemctl enable mdemg-rsic@$USER.timer

# Check timer status
systemctl list-timers --all | grep mdemg-rsic

# Manually trigger the RSIC oneshot (instead of waiting for the timer)
sudo systemctl start mdemg-rsic@$USER
journalctl -u mdemg-rsic@$USER --no-pager -n 10
```

**Expected:** Timer is listed in `list-timers`. Manual trigger executes the RSIC cycle (or reports an error if the space is not configured — that is acceptable for this test).

**Clean up** (stop the service so it does not interfere with remaining tests):

```bash
sudo systemctl stop mdemg@$USER
sudo systemctl disable mdemg@$USER
sudo systemctl disable mdemg-rsic@$USER.timer
```

- [ ] **PASS** — mdemg systemd service starts and serves health check
- [ ] **PASS** — RSIC timer is registered and oneshot executes
- [ ] **SKIP** — non-systemd system (note init system: _______________)

---

### T5.10: Teardown Dry Run (CLI)

```bash
cd ~/mdemg-test
mdemg teardown --dry-run
```

**Expected:** Lists all artifacts that would be removed (server, Docker container/volume, hooks, MCP configs, `.mdemg/` directory, sidebar registration, systemd units if `--full`) without making any changes.

- [ ] **PASS** — dry run lists artifacts without making changes

---

### T5.11: Teardown via Guided Wizard (Sidebar App)

> **Warning:** This removes all MDEMG artifacts for the test project. Run this test LAST (after Sidebar tests) — it replaces the manual cleanup steps below.

1. Open the sidebar app → Config tab → click **"Remove Instance..."**
2. Verify wizard modal shows instance name, project path, and dry-run preview (Step 1: Confirm)
3. Click **Continue** → verify export decision step (Step 2)
4. Click **"Export First"** → verify export setup with profile picker and output path (Step 3)
5. Click **"Back"** → click **"Skip Export"** → verify teardown executes with spinner (Step 4)
6. Verify result shows changes list and backup path (Step 5)
7. Click **Done** → verify instance removed from list

```bash
# Verify cleanup
ls .mdemg 2>/dev/null && echo "FAIL: .mdemg still exists" || echo "OK: .mdemg removed"
mdemg hooks list 2>/dev/null || echo "OK: hooks check (expected to fail — no .mdemg)"
```

- [ ] **PASS** — wizard completes all steps, teardown executes, all artifacts removed, backup created

---

## Sidebar App: MDEMG Desktop Companion (~15 min)

> **Requires:** A Linux desktop environment (GNOME, KDE, XFCE, Cinnamon, MATE, etc.) with a system tray. The sidebar does NOT work on headless servers or in SSH sessions. The MDEMG server must be running (completed Tier 1 above).

The MDEMG Sidebar is a Tauri-based desktop application that provides a visual dashboard for monitoring and controlling MDEMG. It sits in your system tray and shows real-time health status, memory statistics, learning activity, RSIC cycles, server logs, and more — across 7 tabs.

### S.1: Install Sidebar

Choose one installation method:

**Method A — AppImage (recommended, works on any distro):**

```bash
# Download the AppImage
curl -fsSL -o ~/mdemg-sidebar.AppImage \
  "https://github.com/reh3376/mdemg-linux-sidebar/releases/download/v0.2.0/mdemg-sidebar_0.2.0_amd64.AppImage"

# Make it executable
chmod +x ~/mdemg-sidebar.AppImage

# Run it
~/mdemg-sidebar.AppImage &
```

> **Note:** Some distributions require FUSE to run AppImages. If you get an error about `libfuse`, install it:
>
> ```bash
> # Ubuntu/Debian:
> sudo apt install libfuse2
>
> # Fedora:
> sudo dnf install fuse
>
> # If FUSE is not available, extract and run directly:
> ~/mdemg-sidebar.AppImage --appimage-extract
> ./squashfs-root/mdemg-sidebar &
> ```

**Method B — .deb package (Debian/Ubuntu only):**

```bash
# Download the .deb
curl -fsSL -o /tmp/mdemg-sidebar.deb \
  "https://github.com/reh3376/mdemg-linux-sidebar/releases/download/v0.2.0/mdemg-sidebar_0.2.0_amd64.deb"

# Install
sudo dpkg -i /tmp/mdemg-sidebar.deb

# If there are missing dependencies:
sudo apt install -f

# Run
mdemg-sidebar &
```

**Expected:** The sidebar appears in your system tray (notification area). A small icon should be visible. Hover over it to see "MDEMG: Running" (if the server is up) or "MDEMG: Offline" (if not).

> **GNOME users:** GNOME removed the system tray in GNOME 3.26+. You need the [AppIndicator extension](https://extensions.gnome.org/extension/615/appindicator-support/):
>
> ```bash
> # Ubuntu (usually pre-installed):
> sudo apt install gnome-shell-extension-appindicator
> # Then: Settings → Extensions → enable "AppIndicator and KStatusNotifierItem Support"
> # Log out and back in
> ```

- [ ] **PASS** — sidebar installed and system tray icon visible
- [ ] **Method used:** (A) AppImage / (B) .deb
- [ ] **SKIP** — no desktop environment (headless server)

---

### S.2: Sidebar Connection

Click the tray icon (or left-click it) to open the sidebar window.

**Expected:** The window opens showing the **Status** tab with:
- A green dot in the header indicating the server is online
- "MDEMG Sidebar" title
- 7 tabs across the top: Status, Memory, Learning, Neo4j, Config, Logs, RSIC

If the status dot is red (offline), verify the MDEMG server is running:

```bash
curl -s http://localhost:9999/healthz
```

- [ ] **PASS** — sidebar window opens, shows green status, 7 tabs visible

---

### S.3: Browse All Tabs

Click through each tab and verify it loads data (not just "Loading..." forever):

| Tab | What to look for |
|-----|-----------------|
| **Status** | Server status (Running/Offline), subsystem health, model info |
| **Memory** | Total observations count, layer breakdown (L0-L5), health score |
| **Learning** | Hebbian edge counts, learning phase (cold/learning/warm/saturated) |
| **Neo4j** | Database version, node/edge counts, connection pool stats |
| **Config** | Server endpoint, space ID, key-value config pairs, database management (Backup/Migrate), Instance Removal section |
| **Logs** | Recent server log lines (may be empty if server just started) |
| **RSIC** | Engine status, watchdog health, recent cycle history |

> **Tip:** Some tabs (Memory, Learning, RSIC) populate with more data after you've run ingestion and observation tests in Tiers 2-3. If a tab shows mostly zeros or "—", that's expected on a fresh install.

- [ ] **PASS** — all 7 tabs load and display data (or reasonable empty state)

---

### S.4: Test Server Controls

From the **Status** tab, test the lifecycle controls:

1. **Stop the server** using the sidebar's stop button (or via terminal: `mdemg stop`)
2. Verify the sidebar shows "Offline" (red status dot)
3. **Start the server** using the sidebar's start button (or via terminal: `mdemg start --auto-migrate`)
4. Wait ~10 seconds for the health poll to update
5. Verify the sidebar shows "Running" (green status dot)

> **Note:** The sidebar polls the server every 10 seconds, so status changes may take a moment to appear.

- [ ] **PASS** — sidebar reflects server start/stop state changes

---

### S.5: Multi-Instance (Optional)

If you have multiple MDEMG projects, the sidebar supports switching between them. An instance picker dropdown appears when 2+ instances are detected.

```bash
# Create a second test project
mkdir -p ~/mdemg-test-2 && cd ~/mdemg-test-2
mdemg init --defaults
```

The sidebar auto-scans `~/*/` for `.mdemg/config.yaml` markers. Restart the sidebar to trigger a rescan, or wait for the next polling cycle.

- [ ] **PASS** — instance picker visible with 2+ instances
- [ ] **SKIP** — only one project configured

---

## Cleanup / Teardown

### Recommended: Use `mdemg teardown` (if T5.11 was not run)

```bash
cd ~/mdemg-test
mdemg teardown --yes
```

This single command handles steps 1-8 below automatically: stops the server, removes Docker container/volume, uninstalls hooks, cleans MCP/IDE configs, backs up and removes `.mdemg/`, and deregisters from the sidebar app.

### Manual cleanup (fallback)

If `mdemg teardown` is not available or failed:

```bash
# 1. Stop the server
# If using daemon mode:
mdemg stop
# If using foreground mode: press Ctrl+C in the server terminal
# If using systemd:
sudo systemctl stop mdemg@$USER
sudo systemctl disable mdemg@$USER 2>/dev/null

# 2. Close the sidebar app
# Click tray icon → Quit, or kill the process:
pkill -f mdemg-sidebar 2>/dev/null

# 3. Uninstall git hooks
cd ~/mdemg-test
mdemg hooks uninstall

# 4. Stop and remove Neo4j container
mdemg db stop --remove

# 5. Remove Docker volumes
docker volume ls -q --filter name=mdemg | xargs docker volume rm

# 6. Remove MDEMG config (optional — only if uninstalling entirely)
# rm -rf .mdemg

# 7. Clean up test secret
mdemg config set-secret TEST_BETA_KEY ""

# 8. Remove sidebar app (optional — only if uninstalling entirely)
# AppImage: rm ~/mdemg-sidebar.AppImage
# .deb: sudo dpkg --remove mdemg-sidebar

# 9. Remove systemd units (optional — only if uninstalling entirely)
# sudo systemctl disable mdemg@$USER mdemg-rsic@$USER.timer 2>/dev/null
# sudo rm -f /etc/systemd/system/mdemg@.service /etc/systemd/system/mdemg-rsic@.service /etc/systemd/system/mdemg-rsic@.timer
# sudo systemctl daemon-reload
```

### Final cleanup (all methods)

```bash
# Remove test project(s)
rm -rf ~/mdemg-test ~/mdemg-test-2
```

---

## Known Linux Limitations

> **See also:** [README — Troubleshooting](README.md#troubleshooting) for common issues and fixes.

### 1. Daemon Mode (`mdemg start/stop/restart`)

**Issue:** Daemon mode uses Unix process management (PID files, signal handling). It works natively on Linux but may occasionally fail if the PID file becomes stale (e.g., after a system crash or OOM kill).

**Workaround:** If `mdemg start` reports the server is already running but `mdemg status` shows it's not responding:

```bash
# Remove stale PID file
rm -f .mdemg/mdemg.pid

# Restart
mdemg start --auto-migrate
```

For unattended operation, use the systemd service instead of daemon mode:

```bash
sudo systemctl enable --now mdemg@$USER
```

### 2. SELinux on RHEL/Fedora

**Issue:** On distributions with SELinux enforcing (RHEL, Fedora, CentOS), Docker and the MDEMG binary may be restricted by SELinux policies. Symptoms include permission denied errors when Docker tries to mount volumes, or when `mdemg` tries to write to `~/.mdemg/`.

**Workaround:**

```bash
# Check SELinux status
getenforce

# If Enforcing, check for denials related to mdemg or docker
sudo ausearch -m avc -ts recent | grep -E 'mdemg|docker'

# Temporary fix: set SELinux to permissive
sudo setenforce 0

# Permanent fix: add an SELinux policy exception for the mdemg data directory
sudo chcon -R -t container_file_t ~/.mdemg/
# Or for Docker volume mounts, use the :z or :Z suffix in docker run
```

### 3. Docker Engine Memory

**Issue:** Unlike Docker Desktop on macOS (which has a configurable memory limit), Docker Engine on Linux uses all available system memory by default. This is usually fine, but on systems with very limited RAM (< 2 GB), Neo4j may consume excessive memory and trigger the OOM killer.

**Workaround:** Limit the Neo4j container's memory usage:

```bash
# Set memory limit in .mdemg/config.yaml under docker options,
# or pass it via environment variable before starting:
MDEMG_NEO4J_MEMORY_LIMIT=2g mdemg db start
```

Or configure Docker's default memory limits in `/etc/docker/daemon.json`:

```json
{
  "default-runtime": "runc",
  "storage-driver": "overlay2"
}
```

### 4. Keyring on Headless Servers

**Issue:** The `mdemg config set-secret` command uses the Linux system keyring (gnome-keyring, kwallet, or pass). On headless servers without a desktop environment or D-Bus session, keyring operations will fail.

**Workaround:** Use one of these alternatives on headless systems:

```bash
# Option A: Use pass (GPG-based password store, no desktop required)
sudo apt install pass gnupg2   # or: sudo dnf install pass gnupg2
gpg --gen-key
pass init <your-gpg-key-id>

# Option B: Set secrets in .env instead of keyring
echo 'OPENAI_API_KEY=sk-...' >> .env

# Option C: Export as environment variables
export OPENAI_API_KEY=sk-...
```

### 5. Features Requiring an LLM API Key

The following features return degraded or empty results without an OpenAI or Ollama embedding provider configured:

- `recall` — semantic search returns no results
- `consolidation` — concept naming uses fallback (generic names)
- `SME consult` — consulting service unavailable
- `meta-learn` — cross-space generalization unavailable

**Workaround:** Set an OpenAI key in `.env` or via the Linux keyring:

```bash
mdemg config set-secret OPENAI_API_KEY sk-...
# Or in .env:
# OPENAI_API_KEY=sk-...
```

### 6. Web Scraper / Linear Integration

**Issue:** These features require separate API key configuration and external service access.

**Workaround:** Configure in `.env` or via `mdemg config set-secret`:

```bash
# Linear
mdemg config set-secret LINEAR_API_KEY lin_api_...

# Scraper works with public URLs, no key needed
```

### 7. Port Conflicts

**Issue:** If another service is using port 9999, the MDEMG server will fail to start.

**Workaround:** Check what's using the port and either stop it or configure MDEMG to use a different port:

```bash
# Check what's using port 9999
ss -tlnp | grep 9999

# Start server on a different port
LISTEN_ADDR=:10000 mdemg serve --auto-migrate
```

### 8. Firewall (iptables/nftables/firewalld)

**Issue:** Some distributions ship with a firewall enabled by default. If testing from a remote machine, port 9999 may be blocked.

**Workaround:**

```bash
# Check if firewalld is active (Fedora/RHEL)
sudo firewall-cmd --state
sudo firewall-cmd --add-port=9999/tcp --permanent
sudo firewall-cmd --reload

# Or with ufw (Ubuntu)
sudo ufw allow 9999/tcp
```

> **Note:** This is only needed if accessing MDEMG from a remote machine. Local `curl` commands to `localhost` are unaffected by firewall rules.

---

## Feedback & Contributing

We welcome all feedback — bug reports, feature requests, and code contributions. Your experience as a beta tester is invaluable for making MDEMG production-ready on Linux.

### Filing Bug Reports

File issues at: **https://github.com/reh3376/mdemg/issues**

**Title format:** `[Linux Beta] <brief description>`

**Labels:** Add `linux` and `beta-testing`

**Copy and paste this template** into the issue body, filling in each section:

```markdown
**Environment:**
- Distro: (output of `cat /etc/os-release | grep PRETTY_NAME`)
- Kernel: (output of `uname -r`)
- Architecture: (output of `uname -m` — x86_64 or aarch64)
- MDEMG version: (output of `mdemg version`)
- Docker Engine version: (output of `docker --version`)
- Shell: (output of `echo $SHELL`)
- Init system: (systemd / openrc / other)
- Desktop env: (GNOME / KDE / XFCE / None)
- Installation method: curl installer / manual tarball
- Sidebar version: (if applicable — v0.2.0, AppImage or .deb)
- SELinux status: (output of `getenforce` if applicable)

**Test ID:** (e.g., T1.4, T3.7, S.2 — from this beta testing guide)

**Steps to Reproduce:**
1. <exact command>
2. <exact command>

**Expected Result:**
<what should have happened>

**Actual Result:**
<what actually happened — paste full terminal output>

**Server Log (if applicable):**
<output of: tail -50 .mdemg/logs/mdemg.log>

**Journal Log (if using systemd):**
<output of: journalctl -u mdemg@$USER --no-pager -n 50>
```

### Filing Feature Requests

If you think of improvements or missing features while testing, file them at the same issue tracker:

**Title format:** `[Feature Request] <brief description>`

Include:
- What you want to do
- Why it would be useful
- How you imagine it working (even a rough idea helps)

### Contributing Code

We encourage beta testers to contribute fixes and improvements directly. Here's how:

**1. Fork and clone the repo:**

```bash
# Fork via GitHub web UI first, then:
git clone https://github.com/<your-username>/mdemg.git
cd mdemg
git remote add upstream https://github.com/reh3376/mdemg.git
```

**2. Create a feature branch:**

```bash
# Always branch from main
git checkout main
git pull upstream main
git checkout -b fix/your-fix-description    # for bug fixes
# or
git checkout -b feat/your-feature-name      # for new features
```

**3. Make your changes, test them:**

```bash
# Build the CLI
go build -o bin/mdemg ./cmd/mdemg

# Run the linter
golangci-lint run ./...

# Run tests
go test ./...

# Test your changes manually
./bin/mdemg version
```

**4. Commit and push:**

```bash
# Use conventional commit style:
git add <files>
git commit -m "fix: description of what you fixed"
# or: feat: description of new feature
# or: docs: description of doc improvement

git push origin fix/your-fix-description
```

**5. Open a Pull Request:**

Go to your fork on GitHub and click "Compare & pull request". Target the `main` branch on `reh3376/mdemg`. Include:
- What the PR does
- Which test ID (if any) it relates to
- How you tested it

**Branch naming conventions:**

| Prefix | Purpose | Example |
|--------|---------|---------|
| `fix/` | Bug fixes | `fix/daemon-stale-pid` |
| `feat/` | New features | `feat/rpm-package-support` |
| `docs/` | Documentation improvements | `docs/clarify-init-wizard` |
| `refactor/` | Code cleanup (no behavior change) | `refactor/config-loading` |

> **Don't worry about being perfect.** A rough fix is better than no fix. We'll review every PR and help polish it. The goal is collaboration, not perfection.

### Sidebar App Contributions

The sidebar app is in a separate repo: **https://github.com/reh3376/mdemg-linux-sidebar**

It uses Rust (Tauri v2) for the backend and vanilla JavaScript for the frontend. Same fork → branch → PR workflow applies.

### Severity Guide

| Severity | Meaning | Example |
|----------|---------|---------|
| **Critical** | Cannot install or start | Binary won't run, server crashes on start |
| **High** | Core feature broken | Ingest fails, observations not stored |
| **Medium** | Feature degraded | Hooks don't fire, config show incomplete |
| **Low** | Cosmetic or edge case | Minor formatting issue, help text typo |

---

## End of Testing

After completing all tiers, fill in the Results Summary table at the top of this document and submit it along with any issues filed.

Thank you for beta testing MDEMG on Linux! Your feedback directly shapes the product.
