# Symphony Agent for Servo

Autonomous coding agent that watches your Linear project for tasks and implements them — plans, codes, tests, opens PRs, and handles review feedback.

## Quick Start (Claude-assisted)

The fastest way to get set up:

```
git clone https://github.com/servicehelm/symphony.git
cd symphony && git checkout servo && cd servo
```

Then tell Claude: **"Set up Symphony for me"**

Claude will walk you through gathering your keys and getting everything running.

## Manual Setup

### 1. Get Your Keys

| Key | Where to get it |
|-----|----------------|
| **Linear API Key** | Linear > Settings > Security & access > Personal API keys |
| **GitHub Token** | https://github.com/settings/tokens (needs `repo` scope) |

### 2. Add to `.env`

Create a `.env` file in the `servo/` directory:

```bash
LINEAR_API_KEY=lin_api_xxxxx
GITHUB_TOKEN=ghp_xxxxx
```

The default Linear project is the Symphony project. To use a different project, also add:
```bash
SYMPHONY_PROJECT_SLUG=my-project-abc123
```

Codex uses your **ChatGPT subscription** by default (no extra cost). If you need API key billing instead, add `OPENAI_API_KEY=sk-xxxxx` to `.env`.

### 3. Linear Workflow States

Your Linear team needs these custom states (Team Settings > Workflow):
- **QA Review** (after In Progress) — review agent validates the PR automatically
- **Human Review** (after QA Review) — you review after QA passes
- **Merging** (after Human Review)
- **Rework** (loops back to In Progress)

### 4. Build and Run

```bash
git clone https://github.com/servicehelm/symphony.git
cd symphony && git checkout servo && cd servo
docker compose up --build -d
```

### 5. Authenticate Codex

After the container starts, sign in with your ChatGPT subscription:

```bash
docker exec -it servo-symphony codex login --device-auth
# Visit the URL shown, enter the code, authorize in your browser
docker compose restart symphony
```

This uses your existing ChatGPT subscription — no extra API costs. OAuth tokens persist across restarts in a Docker volume, so you only do this once.

> **Alternative**: If you prefer pay-per-use API billing, add `OPENAI_API_KEY=sk-xxxxx` to `.env` and auth happens automatically on startup.

### 6. Verify

```bash
docker compose logs -f symphony
```

You should see it polling Linear every 10 seconds. Create a test Todo issue to verify the full pipeline.

## How It Works

Two independent agents work in sequence:

```
Coding Agent                    Review Agent
────────────                    ────────────
Todo → In Progress → PR done    QA Review → validate PR
                   ↓                      ↓
              QA Review              Pass → Human Review
                                     Fail → Rework (with fixes or feedback)
```

1. **Coding agent** polls Linear, claims a Todo task, implements it, opens PR(s)
2. Moves task to **QA Review** — the review agent picks it up
3. **Review agent** independently validates: builds, tests, lints, runs Playwright E2E, code reviews the diff
4. If QA passes → moves to **Human Review** (you review the PR)
5. If QA finds problems → attempts to fix them. If it can't → moves to **Rework**
6. You approve → move to **Merging** → coding agent merges → Done

## Configuration

Edit `WORKFLOW.md` to adjust:

| Setting | Default | Description |
|---------|---------|-------------|
| `max_concurrent_agents` | 2 | Simultaneous tasks |
| `max_turns` | 20 | Max agent iterations per task |
| `polling.interval_ms` | 10000 | Linear poll frequency (ms) |
| `approval_policy` | never | Codex sandbox policy (never = auto-approve all) |

## Logs

```bash
docker compose logs -f symphony          # Coding agent logs
docker compose logs -f review            # Review agent logs
```

## Troubleshooting

| Problem | Fix |
|---------|-----|
| "No Codex auth found" | Complete step 5 for both containers |
| Agent can't push to GitHub | Verify GITHUB_TOKEN has `repo` scope |
| Agent doesn't pick up issues | Check LINEAR_API_KEY and SYMPHONY_PROJECT_SLUG |
| Container exits immediately | `docker compose logs symphony` or `docker compose logs review` |
| Review agent E2E fails | Check that Go and pnpm deps installed correctly in review container |
