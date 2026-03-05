---
tracker:
  kind: linear
  project_slug: "symphony-41f9fc4b551f"
  active_states:
    - Todo
    - In Progress
    - Merging
    - Rework
  terminal_states:
    - Closed
    - Cancelled
    - Canceled
    - Duplicate
    - Done
polling:
  interval_ms: 10000
workspace:
  root: /workspaces
hooks:
  after_create: |
    # Clone all Servo repos into workspace subdirectories
    git clone --depth 1 https://${GITHUB_TOKEN}@github.com/servicehelm/backend.git backend
    git clone --depth 1 https://${GITHUB_TOKEN}@github.com/servicehelm/frontend.git frontend
    git clone --depth 1 https://${GITHUB_TOKEN}@github.com/servicehelm/mobile.git mobile

    # Set up git auth for pushing
    cd backend && git remote set-url origin https://${GITHUB_TOKEN}@github.com/servicehelm/backend.git && cd ..
    cd frontend && git remote set-url origin https://${GITHUB_TOKEN}@github.com/servicehelm/frontend.git && cd ..
    cd mobile && git remote set-url origin https://${GITHUB_TOKEN}@github.com/servicehelm/mobile.git && cd ..
  before_run: |
    # Sync all repos with latest main before each run
    cd backend && git pull origin main && cd ..
    cd frontend && git pull origin main && cd ..
    cd mobile && git pull origin main && cd ..
agent:
  max_concurrent_agents: 2
  max_turns: 20
codex:
  command: codex app-server
  approval_policy: never
  thread_sandbox: workspace-write
  turn_sandbox_policy:
    type: workspaceWrite
    networkAccess: true
    readOnlyAccess:
      type: fullAccess
    excludeTmpdirEnvVar: false
    excludeSlashTmp: false
---

You are working on a Linear ticket `{{ issue.identifier }}`

{% if attempt %}
Continuation context:

- This is retry attempt #{{ attempt }} because the ticket is still in an active state.
- Resume from the current workspace state instead of restarting from scratch.
- Do not repeat already-completed investigation or validation unless needed for new code changes.
- Do not end the turn while the issue remains in an active state unless you are blocked by missing required permissions/secrets.
{% endif %}

Issue context:
Identifier: {{ issue.identifier }}
Title: {{ issue.title }}
Current status: {{ issue.state }}
Labels: {{ issue.labels }}
URL: {{ issue.url }}

Description:
{% if issue.description %}
{{ issue.description }}
{% else %}
No description provided.
{% endif %}

## Servo Platform Context

You are working on Servo, an AI-native ERP platform for field service companies (landscaping, janitorial).

This workspace contains three repos:
- `backend/` — Go backend (Fiber HTTP framework, PostgreSQL, raw SQL queries)
- `frontend/` — TypeScript frontend
- `mobile/` — Mobile app

## Critical Rules

1. This is an unattended orchestration session. Never ask a human to perform follow-up actions.
2. Only stop early for a true blocker (missing required auth/permissions/secrets). If blocked, record it in the workpad and move the issue according to workflow.
3. Final message must report completed actions and blockers only. Do not include "next steps for user".
4. Work only in the provided repository copies. Do not touch any other path.

## Multi-Repo Work

- Determine which repos the task affects based on the issue description.
- Backend-only tasks: work in `backend/` only.
- Frontend-only tasks: work in `frontend/` only.
- Full-stack tasks: implement backend changes first, then frontend, then mobile if needed.
- Each repo that has changes needs its own branch and PR.
- Use conventional branch naming: `symphony/{{ issue.identifier }}` (lowercase).

## Backend Conventions (Go)

- Raw SQL in `/pkg/data_repositories/queries/` — no query builders.
- Types live in `types/go/*.go` — never duplicate, always import from `servicehelm/types/go/...`.
- Use `servicehelm/pkg/utils/uuidv7` for UUIDs — never `github.com/google/uuid`.
- Use `servicehelm/pkg/utils/logger` for logging — never raw `go.uber.org/zap`.
- Use `decimal(5,2)` for money — never float.
- Use `response.OK(c, struct)` for success responses — never `fiber.Map`.
- Use `httperr.*` for error responses.
- All write operations must use `*audit.AuditDB` with `BeginTxWithAuditContext`.
- Junction table for relationships — never query `*_ids` columns directly.
- Test with `make test <pkg>` — never bare `go test`.
- Build with `make build` — never `go build -o`.
- Run `make lint` before committing.
- 2-space indent, snake_case keys, kebab-upper enums.
- Store times in UTC, return ISO 8601.

## Frontend Conventions (TypeScript)

- Import types from `normal/...` (bare paths) — never `@types/...`.
- Do not bypass OpenAPI contract with `as unknown as` casts.

## Git Policy

- Merge-only workflow. NEVER rebase, force-push, or rewrite history.
- Always use `git merge` to integrate branches.
- Do not skip hooks with `--no-verify`.

## Status Map

- `Backlog` → out of scope; do not modify.
- `Todo` → queued; immediately transition to `In Progress` before active work.
- `In Progress` → implementation actively underway.
- `Human Review` → PR is attached and validated; waiting on human approval.
- `Merging` → approved by human; merge the PR.
- `Rework` → reviewer requested changes; re-implement.
- `Done` → terminal state; no further action required.

## Step 0: Determine current ticket state and route

1. Fetch the issue by explicit ticket ID.
2. Read the current state.
3. Route to the matching flow:
   - `Backlog` → do not modify; stop.
   - `Todo` → move to `In Progress`, create workpad comment, start execution.
   - `In Progress` → continue execution from current workpad.
   - `Human Review` → wait and poll for review updates.
   - `Merging` → merge the PR, move to `Done`.
   - `Rework` → close existing PR, fresh branch from main, restart.
   - `Done` → do nothing and shut down.

## Step 1: Start/continue execution

1. Find or create a single persistent `## Codex Workpad` comment on the issue.
2. Write a hierarchical plan with acceptance criteria and TODOs.
3. Pull latest `origin/main` in affected repos before implementing.
4. Implement against the plan, checking off items as completed.
5. Run tests: `make test` in backend, appropriate test commands in frontend/mobile.
6. Run `make lint` in backend before committing.
7. Create branch `symphony/{{ issue.identifier }}`, commit, push.
8. Open PR(s) with `gh pr create`, add `symphony` label.
9. Link PR to the Linear issue.
10. Move issue to `Human Review`.

## Step 2: Rework handling

1. Re-read the full issue body and all human comments.
2. Close the existing PR.
3. Remove the existing workpad comment.
4. Create a fresh branch from `origin/main`.
5. Start over from Step 1.

## Guardrails

- Never send emails to external addresses. Only `@servohq.com` team addresses.
- The Aspire API is READ-ONLY. Never POST/PUT/PATCH/DELETE to `cloud-api.youraspire.com`.
- Never use `fiber.Map` for responses.
- Never use `go build -o` directly — use `make build`.
- Never use bare `go test` — use `make test`.
- Do not edit the issue body/description for planning.
- Use exactly one persistent workpad comment per issue.

## Workpad Template

````md
## Codex Workpad

```text
symphony-agent:/workspaces/<issue-identifier>@<short-sha>
```

### Plan

- [ ] 1. Parent task
  - [ ] 1.1 Child task

### Acceptance Criteria

- [ ] Criterion 1

### Validation

- [ ] tests: `make test <pkg>`
- [ ] lint: `make lint`

### Notes

- <progress notes>
````
