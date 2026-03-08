# Symphony Agent Setup (for Claude)

When a user asks you to set up Symphony, follow these steps exactly. Be proactive — don't ask the user to go get keys, open the pages for them.

## Prerequisites Check

1. Confirm Docker is installed: `docker --version`
2. Confirm they're in the symphony repo root (clone from https://github.com/servicehelm/symphony, checkout the `servo` branch)

## Step 1: Get Linear API Key

Open the Linear API key page in their browser:

```
mcp__claude-in-chrome__navigate → https://linear.app/settings/api
```

Tell the user: "I've opened Linear's API settings. Create a Personal API key and paste it here."

Wait for them to paste the key.

## Step 2: Get GitHub Token

Open the GitHub token creation page in their browser:

```
mcp__claude-in-chrome__navigate → https://github.com/settings/tokens/new?scopes=repo&description=Symphony+Agent
```

Tell the user: "I've opened GitHub's token page. The `repo` scope is pre-selected. Generate the token and paste it here."

Wait for them to paste the token.

## Step 3: Add to .env

Create a `.env` file in the `servo/` directory:

```
LINEAR_API_KEY=<their key>
GITHUB_TOKEN=<their token>
```

Then tell the user:

> Symphony is configured to watch the **Symphony** Linear project (`symphony-41f9fc4b551f`) by default.
> It can only watch one project at a time. If you want to point it at a different project,
> add `SYMPHONY_PROJECT_SLUG=<your-slug>` to `.env`. You can find the slug in the project URL.

## Step 4: Linear Workflow States

Their Linear team needs these custom states (Team Settings > Workflow). They may already exist:
- **QA Review** (type: Started, after In Progress) — automated review agent validates the PR
- **Human Review** (type: Started, after QA Review) — human reviews after QA passes
- **Merging** (type: Started, after Human Review)
- **Rework** (type: Started, loops back)

If the states already exist for their team, no action needed.

## Step 5: Build and Start

```bash
cd servo
docker compose up --build -d
```

This starts the Symphony agent container which handles all workflow states:
- Coding (Todo/In Progress/Merging/Rework)
- QA Review (independent code review)

## Step 6: Codex Authentication (ChatGPT Subscription)

Run device auth:

```bash
docker exec -it servo-symphony codex login --device-auth
```

This outputs a URL and code. Open the URL in the user's browser using `mcp__claude-in-chrome__navigate`, and tell them to enter the code and authorize with their ChatGPT account.

Then restart:

```bash
cd servo && docker compose restart
```

Codex uses their existing ChatGPT subscription — no extra API costs. OAuth tokens persist in Docker volumes, so they only do this once.

## Step 7: Verify

```bash
docker compose logs -f symphony
```

They should see Symphony polling Linear every 10 seconds. Create a test Todo issue in their Linear project to verify the full pipeline.

## Troubleshooting

- **"No Codex auth found"** — They need to complete Step 6
- **Container exits immediately** — Check `docker compose logs symphony` for errors
- **Agent can't push to GitHub** — Verify GITHUB_TOKEN has `repo` scope
- **Agent doesn't pick up issues** — Verify LINEAR_API_KEY is correct and SYMPHONY_PROJECT_SLUG matches their project
- **Model errors** — Default model is gpt-5.4. Edit `/root/.codex/config.toml` inside the container to change it

## Architecture Notes

- Symphony is an Elixir escript that polls Linear and spawns Codex CLI agents
- Each task gets an isolated workspace at `/workspaces/<issue-id>/` with all three repos cloned
- Codex runs with `networkAccess: true` so it can git push and create PRs
- Config lives in `WORKFLOW.md` (YAML front matter + Jinja2 prompt template)
- Three Docker volumes persist workspaces, logs, and Codex auth across restarts
