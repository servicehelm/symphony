#!/bin/bash
# Wrapper to log all Codex app-server output for debugging
exec codex app-server 2>&1 | tee -a /app/log/codex-raw.log
