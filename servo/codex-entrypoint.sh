#!/bin/bash
set -euo pipefail

# ── Codex config ──────────────────────────────────────────────
if [ ! -f /root/.codex/config.toml ]; then
  mkdir -p /root/.codex
  echo 'model = "gpt-5.4"' > /root/.codex/config.toml
fi

# ── Template WORKFLOW.md with env vars ────────────────────────
# Replace placeholder with env var so each user can set their own project slug
if [ -n "${SYMPHONY_PROJECT_SLUG:-}" ]; then
  sed -i "s|project_slug:.*|project_slug: \"${SYMPHONY_PROJECT_SLUG}\"|" /app/WORKFLOW.md
  echo "[entrypoint] Project slug set to: ${SYMPHONY_PROJECT_SLUG}"
fi

# ── Codex auth (OAuth / ChatGPT subscription only) ─────────────
if [ -f /root/.codex/auth.json ]; then
  echo "[entrypoint] Using OAuth auth."
else
  echo ""
  echo "╔══════════════════════════════════════════════════════════╗"
  echo "║  Sign in with your ChatGPT subscription:                ║"
  echo "║                                                         ║"
  echo "║  Run in another terminal:                               ║"
  echo "║    docker exec -it servo-symphony \                     ║"
  echo "║      codex login --device-auth                          ║"
  echo "║                                                         ║"
  echo "║  Then restart:                                          ║"
  echo "║    docker compose restart symphony                      ║"
  echo "╚══════════════════════════════════════════════════════════╝"
  echo ""
  sleep 3600
  exit 1
fi

echo "[entrypoint] Auth OK. Starting Symphony..."
exec /app/bin/symphony --i-understand-that-this-will-be-running-without-the-usual-guardrails /app/WORKFLOW.md
