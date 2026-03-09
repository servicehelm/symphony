---
tracker:
  kind: linear
  project_slug: "symphony-41f9fc4b551f"
  active_states:
    - Todo
    - In Progress
    - QA Review
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
  timeout_ms: 120000
  after_create: |
    export PATH="/usr/local/go/bin:/root/go/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

    git clone --depth 1 https://${GITHUB_TOKEN}@github.com/servicehelm/backend.git backend
    git clone --depth 1 https://${GITHUB_TOKEN}@github.com/servicehelm/frontend.git frontend
    git clone --depth 1 https://${GITHUB_TOKEN}@github.com/servicehelm/mobile.git mobile

    cd backend && git remote set-url origin https://${GITHUB_TOKEN}@github.com/servicehelm/backend.git && git config submodule.types.url https://${GITHUB_TOKEN}@github.com/servicehelm/types.git && git submodule update --init --depth 1 && cd ..
    cd frontend && git remote set-url origin https://${GITHUB_TOKEN}@github.com/servicehelm/frontend.git && git config submodule.types.url https://${GITHUB_TOKEN}@github.com/servicehelm/types.git && git submodule update --init --depth 1 && cd ..
    cd mobile && git remote set-url origin https://${GITHUB_TOKEN}@github.com/servicehelm/mobile.git && cd ..

    cd backend && go mod download && cd ..
    cd frontend && pnpm install && cd ..

    # Write backend .env so make test/run can find database and redis
    echo "ENV=development" > backend/.env
    echo "PORT=8080" >> backend/.env
    echo "HOST=0.0.0.0" >> backend/.env
    echo "DATABASE_URL=${DATABASE_URL}" >> backend/.env
    echo "TEST_DATABASE_URL=${TEST_DATABASE_URL}" >> backend/.env
    echo "TEST_DATABASE_URL_DIRECT=${TEST_DATABASE_URL_DIRECT}" >> backend/.env
    echo "TEST_ATLAS_DEV_URL=${TEST_ATLAS_DEV_URL}" >> backend/.env
    echo "DEVELOPMENT_DATABASE_URL=${DEVELOPMENT_DATABASE_URL}" >> backend/.env
    echo "REDIS_URL=${REDIS_URL}" >> backend/.env
    echo "TEST_REDIS_URL=${TEST_REDIS_URL}" >> backend/.env
    echo "DEVELOPMENT_REDIS_URL=${DEVELOPMENT_REDIS_URL}" >> backend/.env
    echo "REDIS_HOST=${REDIS_HOST}" >> backend/.env
    echo "REDIS_PORT=${REDIS_PORT}" >> backend/.env

    # Create test database if it doesn't exist
    PGPASSWORD=servo_dev psql -h postgres -U servo -d servo -tc "SELECT 1 FROM pg_database WHERE datname = 'servo_test'" | grep -q 1 || PGPASSWORD=servo_dev psql -h postgres -U servo -d servo -c "CREATE DATABASE servo_test"
  before_run: |
    export PATH="/usr/local/go/bin:/root/go/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

    cd backend && git pull origin main && git config submodule.types.url https://${GITHUB_TOKEN}@github.com/servicehelm/types.git && git submodule update --init --depth 1 && cd ..
    cd frontend && git pull origin main && git config submodule.types.url https://${GITHUB_TOKEN}@github.com/servicehelm/types.git && git submodule update --init --depth 1 && cd ..
    cd mobile && git pull origin main && cd ..

    cd backend && go mod download && cd ..
    cd frontend && pnpm install && cd ..

    # Refresh backend .env
    echo "ENV=development" > backend/.env
    echo "PORT=8080" >> backend/.env
    echo "HOST=0.0.0.0" >> backend/.env
    echo "DATABASE_URL=${DATABASE_URL}" >> backend/.env
    echo "TEST_DATABASE_URL=${TEST_DATABASE_URL}" >> backend/.env
    echo "TEST_DATABASE_URL_DIRECT=${TEST_DATABASE_URL_DIRECT}" >> backend/.env
    echo "TEST_ATLAS_DEV_URL=${TEST_ATLAS_DEV_URL}" >> backend/.env
    echo "DEVELOPMENT_DATABASE_URL=${DEVELOPMENT_DATABASE_URL}" >> backend/.env
    echo "REDIS_URL=${REDIS_URL}" >> backend/.env
    echo "TEST_REDIS_URL=${TEST_REDIS_URL}" >> backend/.env
    echo "DEVELOPMENT_REDIS_URL=${DEVELOPMENT_REDIS_URL}" >> backend/.env
    echo "REDIS_HOST=${REDIS_HOST}" >> backend/.env
    echo "REDIS_PORT=${REDIS_PORT}" >> backend/.env
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

## Instructions

1. Work only in the provided repository copies. Do not touch any other path.
2. If blocked by missing tools/auth/permissions, use the blocked-access escape hatch — do NOT spin burning tokens.
3. Final message must report completed actions and blockers only. Do not include "next steps for user".
4. Operate autonomously end-to-end unless blocked by missing requirements, secrets, or permissions.

## Servo Platform Context

You are working on Servo, an AI-native ERP platform for field service companies (landscaping, janitorial).

This workspace contains three repos:
- `backend/` — Go backend (Fiber HTTP framework, PostgreSQL, raw SQL queries)
- `frontend/` — TypeScript frontend (Next.js)
- `mobile/` — Mobile app

## Default Posture

- Start by determining the ticket's current status, then follow the matching flow.
- Start every task by opening the tracking workpad comment and bringing it up to date.
- Spend extra effort up front on planning and verification design before implementation.
- Reproduce first: confirm the current behavior/issue before changing code.
- Keep ticket metadata current (state, checklist, acceptance criteria, links).
- Use a single persistent workpad comment as the source of truth for progress.
- When meaningful out-of-scope improvements are discovered, file a separate Linear issue in `Backlog` with the same project, a `related` link to the current issue, and `blockedBy` when the follow-up depends on this issue. Do not expand current scope.
- Move status only when the matching quality bar is met.

## Multi-Repo Work

- Determine which repos the task affects based on the issue description.
- Backend-only tasks: work in `backend/` only.
- Frontend-only tasks: work in `frontend/` only.
- Full-stack tasks: implement backend changes first, then frontend, then mobile if needed.
- Each repo that has changes needs its own branch and PR.
- Use conventional branch naming: `symphony/{{ issue.identifier }}` (lowercase).

## Development Servers

When you need to verify full-stack behavior (e.g., testing API integration, debugging frontend-backend interactions), start both dev servers concurrently.

**IMPORTANT:** Do NOT use `make run` or `make dev` — those targets try to manage Docker containers which are not available inside this workspace. Use direct commands instead:

- **Backend**: `cd backend && go run cmd/main.go &` (Go Fiber server on port 8080, runs in background)
- **Frontend**: `cd frontend && pnpm dev &` (Next.js dev server on port 3000, runs in background)

Tips:
- The backend `.env` is pre-configured with database and Redis connection URLs. Do not override them.
- Start backend first — frontend may depend on API endpoints.
- Use `curl` or `wget` to smoke-test backend endpoints before relying on frontend.
- Kill background servers when done: `kill %1 %2` or `pkill -f "go run"` / `pkill -f "next dev"`.
- If the backend fails to start due to missing migrations, run: `cd backend && atlas migrate apply --env test --allow-dirty --exec-order=non-linear`
- The workspace has PostgreSQL (at hostname `postgres:5432`) and Redis (at hostname `redis:6379`) available as sidecar services. They are NOT on localhost.

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
  - Special case: if a PR is already attached, treat as feedback/rework loop.
- `In Progress` → implementation actively underway.
- `QA Review` → switch to review mode (Step 5). You are now an independent reviewer.
- `Human Review` → PR is attached and validated; waiting on human approval.
- `Merging` → approved by human; merge the PR, move to `Done`.
- `Rework` → reviewer or QA agent found problems; re-implement.
- `Done` → terminal state; no further action required.

## Step 0: Determine current ticket state and route

1. Fetch the issue by explicit ticket ID.
2. Read the current state and all comments (especially human comments).
3. Route to the matching flow:
   - `Backlog` → do not modify; stop.
   - `Todo` → move to `In Progress`, ensure workpad exists, start execution (Step 1).
     - If PR is already attached, start by reviewing all open PR comments.
   - `In Progress` → continue execution from current workpad (Step 1).
   - `QA Review` → run QA review flow (Step 5).
   - `Human Review` → poll for review updates (Step 3).
   - `Merging` → merge the PR, move to `Done` (Step 3).
   - `Rework` → run rework flow (Step 4).
   - `Done` → do nothing; shut down.
4. Check whether a PR already exists for the branch and whether it is closed.
   - If closed/merged, create a fresh branch from `origin/main` and restart.

## Step 1: Start/continue execution

1. Find or create a single persistent `## Codex Workpad` comment on the issue.
   - Search existing comments for `## Codex Workpad`. If found, reuse it.
   - If not found, create one. Persist its ID and only update that comment.
2. Immediately reconcile the workpad:
   - Check off items that are already done.
   - Expand/fix the plan for current scope.
   - Ensure `Acceptance Criteria` and `Validation` are current.
3. Add an environment stamp at the top: `symphony-agent:<abs-path>@<short-sha>`
4. Write a hierarchical plan with acceptance criteria and TODOs.
   - If the ticket has `Validation`, `Test Plan`, or `Testing` sections, copy them into the workpad as required checkboxes.
5. Run a self-review of the plan and refine before implementing.
6. Reproduce the current behavior first when applicable. Record the signal in Notes.
7. Pull latest `origin/main` in affected repos before implementing.
8. Implement against the plan, checking off items as completed.
   - Update the workpad immediately after each meaningful milestone.
   - Never leave completed work unchecked in the plan.
9. Run tests: `make test` in backend, appropriate test commands in frontend/mobile.
10. Run `make lint` in backend before committing.
11. Create branch `symphony/{{ issue.identifier }}`, commit, push.
12. Open PR(s) with `gh pr create`, add `symphony` label.
13. Link PR to the Linear issue.
14. Before moving to QA Review, verify the completion bar is met.
15. Move issue to `QA Review`.

## Step 2: PR feedback sweep (required before handoff)

When a ticket has an attached PR, run this before moving to `QA Review`:

1. Gather feedback from all channels:
   - Top-level PR comments (`gh pr view --comments`).
   - Inline review comments (`gh api repos/servicehelm/<repo>/pulls/<pr>/comments`).
   - Review summaries (`gh pr view --json reviews`).
2. Treat every actionable reviewer comment as blocking until:
   - Code/test/docs updated to address it, OR
   - Explicit, justified pushback reply is posted on that thread.
3. Update the workpad to include each feedback item and resolution.
4. Re-run validation after feedback-driven changes and push updates.
5. Repeat until no outstanding actionable comments remain.

## Step 3: Human Review and merge handling

1. When in `Human Review`, do not code or change ticket content. Poll for updates.
2. If review feedback requires changes, follow rework flow (Step 4).
3. If approved, human moves to `Merging`.
4. When in `Merging`, merge the PR with `gh pr merge --merge`, then move to `Done`.

## Step 4: Rework handling

1. Treat `Rework` as a full approach reset, not incremental patching.
2. Re-read the full issue body and all human comments. Identify what must change.
3. Close the existing PR.
4. Remove the existing `## Codex Workpad` comment.
5. Create a fresh branch from `origin/main`.
6. Start over from Step 1 with a new workpad and fresh plan.

## Step 5: QA Review (independent reviewer mode)

When the issue is in `QA Review`, you switch roles. You are now an **independent reviewer** — you did NOT write the code. Your job is qualitative: does the implementation actually solve the problem correctly, and does it follow Servo conventions?

You are NOT a CI system. The coding agent already ran build, tests, and lint. Do not re-run those. Your value is a fresh set of eyes on the code.

### 5.1 Find the PR

```bash
gh pr list --search "{{ issue.identifier }}" --state open --json number,headRefBranch,url
```

No PR found → comment "QA Review: no PR found" → move to `Rework` → stop.

### 5.2 Read the diff

```bash
gh pr diff <pr-number>
```

Read the entire diff carefully. This is your primary input.

### 5.3 Qualitative review

Answer these questions:

**Does it solve the problem?**
- Re-read the issue description and acceptance criteria.
- Does every requirement have corresponding code?
- Are there edge cases the implementation misses?

**Is it correct?**
- Trace the logic. Would this actually work at runtime?
- Are there off-by-one errors, nil pointer risks, or race conditions?
- For SQL: are queries correct? Do they join properly? Are WHERE clauses right?

**Does it follow Servo conventions?**
- Typed response structs (not `fiber.Map`)
- `*audit.AuditDB` for writes with `BeginTxWithAuditContext`
- `tenant_id` filters on all multi-tenant queries
- Junction table for relationships (never query `*_ids` directly)
- `uuidv7` for UUIDs (never `google/uuid`)
- `response.OK(c, struct)` for success, `httperr.*` for errors
- Raw SQL in query functions (no query builders)

**Is anything suspicious?**
- Hardcoded values that should be configurable
- Security issues (SQL injection, missing auth checks, exposed secrets)
- Dead code or leftover debug statements

### 5.4 Verdict

Keep your review comment SHORT.

**If the code looks good:**
1. Comment on the PR: "## QA Review: PASSED" with 1-2 sentences on what you verified.
2. Move issue to `Human Review`.

**If you find real problems (not nitpicks):**
1. Try to fix them yourself — push to the PR branch, max 2 fix attempts.
2. If fixed → comment "QA Review: PASSED (with fixes)" → move to `Human Review`.
3. If unfixable → comment with specific findings → move to `Rework`.

**What is NOT a blocker:** style preferences, missing comments on simple code, variable naming opinions, "could be refactored" suggestions. Only block on real bugs, missing requirements, or convention violations.

## Blocked-access escape hatch

Use this ONLY when blocked by missing required tools, auth, or permissions that cannot be resolved in-session.

- Do NOT spin retrying. If you've tried 2-3 approaches and are still blocked, use this.
- GitHub access issues are NOT a valid blocker by default — try fallback strategies first.
- When truly blocked:
  1. Update the workpad with a `### Blocked` section containing:
     - What is missing
     - Why it blocks required work
     - Exact human action needed to unblock
  2. Move the issue to `Human Review` with the blocker documented.
  3. Stop. Do not continue burning tokens.

## Completion bar (required before QA Review)

All of these must be true before moving to `QA Review`:

- [ ] Workpad checklist is fully complete and accurate.
- [ ] Acceptance criteria are met.
- [ ] All ticket-provided validation/test-plan items are marked complete.
- [ ] Tests pass for the latest commit.
- [ ] Lint passes.
- [ ] PR feedback sweep is complete — no actionable comments remain.
- [ ] PR checks are green, branch is pushed, PR is linked on the issue.
- [ ] PR has `symphony` label.
- [ ] Workpad is up to date with final status.

## Guardrails

- Never send emails to external addresses. Only `@servohq.com` team addresses.
- The Aspire API is READ-ONLY. Never POST/PUT/PATCH/DELETE to `cloud-api.youraspire.com`.
- Never use `fiber.Map` for responses — use typed structs.
- Never use `go build -o` directly — use `make build`.
- Never use bare `go test` — use `make test`.
- Do not edit the issue body/description for planning.
- Use exactly one persistent workpad comment per issue.
- If branch PR is already closed/merged, do not reuse — create fresh branch from `origin/main`.
- Temporary proof edits (for local verification) must be reverted before commit.
- Do not move to `QA Review` unless the completion bar is satisfied.
- In `Human Review`, do not make changes; wait and poll.
- If state is terminal (`Done`), do nothing and shut down.

## Workpad template

````md
## Codex Workpad

```text
symphony-agent:<abs-path>@<short-sha>
```

### Plan

- [ ] 1. Parent task
  - [ ] 1.1 Child task
  - [ ] 1.2 Child task
- [ ] 2. Parent task

### Acceptance Criteria

- [ ] Criterion 1
- [ ] Criterion 2

### Validation

- [ ] targeted tests: `<command>`

### Notes

- <short progress note>

### Confusions

- <only include when something was unclear during execution>
````
