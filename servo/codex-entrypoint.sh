#!/bin/bash
set -euo pipefail

# ── Codex config ──────────────────────────────────────────────
if [ ! -f /root/.codex/config.toml ]; then
  mkdir -p /root/.codex
  echo 'model = "gpt-5.4-2026-03-05"' > /root/.codex/config.toml
fi

# ── Template WORKFLOW.md with env vars ────────────────────────
# Replace placeholder with env var so each user can set their own project slug
if [ -n "${SYMPHONY_PROJECT_SLUG:-}" ]; then
  sed -i "s|project_slug:.*|project_slug: \"${SYMPHONY_PROJECT_SLUG}\"|" /app/WORKFLOW.md
  echo "[entrypoint] Project slug set to: ${SYMPHONY_PROJECT_SLUG}"
fi

# ── Codex auth (OAuth only — no API keys) ─────────────────────
# Reject API key auth to prevent accidental quota billing
if [ -n "${OPENAI_API_KEY:-}" ]; then
  echo "[entrypoint] WARNING: OPENAI_API_KEY is set but API key auth is disabled."
  echo "[entrypoint] Remove OPENAI_API_KEY from .env and use device-auth instead."
fi

# Require OAuth device auth (ChatGPT subscription)
if [ ! -f /root/.codex/auth.json ]; then
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
  # Sleep so container stays up for the login command
  sleep 3600
  exit 1
fi

echo "[entrypoint] Auth OK. Starting Symphony..."
exec /app/bin/symphony --i-understand-that-this-will-be-running-without-the-usual-guardrails /app/WORKFLOW.md
