# Symphony Orchestrator for Servo
# Runs the Elixir reference implementation with Codex CLI
#
# Build: docker compose build
# Run:   docker compose up

# Stage 1: Build the Symphony escript
FROM hexpm/elixir:1.19-erlang-26.2.5.4-debian-bookworm-20260223 AS builder

RUN apt-get update && apt-get install -y git make && rm -rf /var/lib/apt/lists/*

WORKDIR /build
RUN git clone --depth 1 https://github.com/openai/symphony /build/symphony

WORKDIR /build/symphony/elixir
RUN mix local.hex --force && mix local.rebar --force
RUN mix setup
RUN mix build

# Stage 2: Runtime (same Erlang/Elixir base for compat)
FROM hexpm/elixir:1.19-erlang-26.2.5.4-debian-bookworm-20260223

RUN apt-get update && apt-get install -y \
  curl \
  git \
  openssh-client \
  ca-certificates \
  gnupg \
  && rm -rf /var/lib/apt/lists/*

# Install Node.js 22 (for Codex CLI)
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
  && apt-get install -y nodejs \
  && rm -rf /var/lib/apt/lists/*

# Install OpenAI Codex CLI
RUN npm install -g @openai/codex

# Install GitHub CLI (for PR creation by agents)
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | gpg --dearmor -o /usr/share/keyrings/githubcli.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
  && apt-get update && apt-get install -y gh && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy built Symphony escript from builder
COPY --from=builder /build/symphony/elixir/bin/symphony /app/bin/symphony

# Copy our config files
COPY WORKFLOW.md /app/WORKFLOW.md
COPY git-askpass.sh /app/git-askpass.sh
RUN sed -i 's/\r$//' /app/git-askpass.sh && chmod +x /app/git-askpass.sh

# Git config for the agent
RUN git config --global user.name "Symphony Agent" \
  && git config --global user.email "symphony@servohq.com" \
  && git config --global init.defaultBranch main

# Codex config — set default model
RUN mkdir -p /root/.codex && echo 'model = "gpt-5.4-2026-03-05"' > /root/.codex/config.toml

# Codex login script — runs at container start to authenticate with API key
COPY codex-entrypoint.sh /app/codex-entrypoint.sh
RUN sed -i 's/\r$//' /app/codex-entrypoint.sh && chmod +x /app/codex-entrypoint.sh

# Workspace and log directories
RUN mkdir -p /workspaces /app/log

ENTRYPOINT ["/app/codex-entrypoint.sh"]
