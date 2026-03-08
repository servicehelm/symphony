# Symphony Agent Authentication

## Policy: OAuth Only (No API Keys)

Symphony agents use **ChatGPT subscription OAuth** exclusively. API key auth is disabled
in the entrypoint to prevent accidental usage-based billing.

## How It Works

- OAuth tokens are stored in Docker volumes (`servo_symphony_codex`, `servo_review_codex`)
- The Codex CLI auto-refreshes tokens using the stored refresh token
- Tokens survive container rebuilds and restarts
- **You should only need to auth once** — unless you delete the Docker volumes

## Initial Setup (One-Time)

### Option A: Setup Script

```bash
cd servo
bash setup-auth.sh
```

This handles both containers interactively.

### Option B: Manual / Non-Interactive (e.g., from Claude Code)

Since the device-auth flow needs a TTY for interactive use, but can also be run
non-interactively by capturing the device code:

1. **Start the auth flow** (from any terminal, doesn't need TTY):
   ```bash
   docker exec servo-symphony bash -c 'timeout 300 codex login --device-auth 2>&1'
   ```

2. **Capture the output** — it will show:
   ```
   1. Open this link in your browser and sign in to your account
      https://auth.openai.com/codex/device

   2. Enter this one-time code (expires in 15 minutes)
      XXXX-XXXXX
   ```

3. **Go to https://auth.openai.com/codex/device** in your browser

4. **Enter the code** and sign in with your ChatGPT account

5. The CLI polls in the background and saves `auth.json` automatically

6. **Repeat for the review agent**:
   ```bash
   docker exec servo-symphony-review bash -c 'timeout 300 codex login --device-auth 2>&1'
   ```

7. **Restart both containers**:
   ```bash
   cd servo && docker compose restart
   ```

### Gotchas

- **Rate limiting**: Don't spam device-auth attempts. If you get `429 Too Many Requests`,
  wait 2-3 minutes before retrying.
- **Code expiry**: Device codes expire in 15 minutes. Complete the browser step promptly.
- **One at a time**: Auth one container, then the other. Don't run both simultaneously.
- **Volume persistence**: Auth survives `docker compose down` and `docker compose build`.
  Only `docker volume rm servo_symphony_codex` destroys it.

## Verifying Auth

```bash
# Check if auth exists
docker exec servo-symphony bash -c 'cat /root/.codex/auth.json | head -3'

# Check via codex
docker exec servo-symphony bash -c 'codex login status'
```

## Re-Auth (If Needed)

If tokens somehow expire or volumes are deleted:

```bash
# Remove stale auth
docker exec servo-symphony bash -c 'rm -f /root/.codex/auth.json'

# Re-run device auth
docker exec servo-symphony bash -c 'timeout 300 codex login --device-auth 2>&1'
# Enter the code at https://auth.openai.com/codex/device

# Restart
cd servo && docker compose restart
```
