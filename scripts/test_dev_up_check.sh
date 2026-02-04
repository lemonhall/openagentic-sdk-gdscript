#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export OPENAI_API_KEY="sk-test"
export OPENAGENTIC_MEDIA_BEARER_TOKEN="dev-token"

bash ./dev-up.sh --check --no-daemon

