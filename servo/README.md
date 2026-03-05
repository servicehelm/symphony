# Symphony Agent for Servo

Autonomous coding agent that watches your Linear project for tasks and implements them — plans, codes, tests, opens PRs, and handles review feedback.

## Quick Start (Claude-assisted)

The fastest way to get set up:

```
cd agents/symphony
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

Add to the root `.env` file:

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
- **Human Review** (after In Progress)
- **Merging** (after Human Review)
- **Rework** (loops back to In Progress)

### 4. Build and Run

```bash
cd agents/symphony
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

1. Polls Linear every 10s for Todo/In Progress/Merging/Rework tasks
2. Claims a task, creates isolated workspace, clones backend + frontend + mobile
3. Codex agent reads the task, plans, implements, tests, opens PR(s)
4. Moves task to **Human Review** — you review the PR
5. Approve and move to **Merging** — agent merges, moves to Done
6. Request changes and move to **Rework** — agent re-implements

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
docker compose logs -f symphony          # Live logs
docker volume inspect symphony_logs      # Log volume location
```

## Troubleshooting

| Problem | Fix |
|---------|-----|
| "No Codex auth found" | Complete step 5 (API key or device auth) |
| Agent can't push to GitHub | Verify GITHUB_TOKEN has `repo` scope |
| Agent doesn't pick up issues | Check LINEAR_API_KEY and SYMPHONY_PROJECT_SLUG |
| Container exits immediately | `docker compose logs symphony` for errors |
