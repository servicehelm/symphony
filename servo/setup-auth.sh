#!/bin/bash
# One-time OAuth setup for Symphony agents.
# Auth tokens persist in Docker volumes (servo_symphony_codex, servo_review_codex)
# and auto-refresh — you should never need to run this again.

set -euo pipefail
cd "$(dirname "$0")"

echo "=== Symphony OAuth Setup ==="
echo ""
echo "This will open your browser twice to authorize with your ChatGPT subscription."
echo "Tokens persist in Docker volumes and auto-refresh."
echo ""

# Ensure containers are running
docker compose up -d 2>/dev/null

echo "--- Authenticating coding agent (servo-symphony) ---"
winpty docker exec -it servo-symphony codex login --device-auth
echo ""

echo "--- Authenticating review agent (servo-symphony-review) ---"
winpty docker exec -it servo-symphony-review codex login --device-auth
echo ""

echo "--- Restarting containers ---"
docker compose restart
echo ""
echo "=== Done! Auth tokens are saved in Docker volumes. ==="
echo "=== You should never need to run this again. ==="
