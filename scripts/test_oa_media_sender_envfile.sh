#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

tmp_env="$(mktemp)"
tmp_file="$(mktemp)"
trap 'rm -f "$tmp_env" "$tmp_file"' EXIT

cat >"$tmp_env" <<'EOF'
OPENAGENTIC_MEDIA_BASE_URL="http://127.0.0.1:8788"
OPENAGENTIC_MEDIA_BEARER_TOKEN="dev-token"
OA_IRC_HOST="127.0.0.1"
OA_IRC_PORT="6667"
OA_SENDER_IRC_CHANNEL="#test"
OA_SENDER_IRC_NICK="oa_sender"
OA_SENDER_IRC_MAX_LEN="360"
EOF

echo "hello" >"$tmp_file"

python scripts/oa_media_sender.py --check --env-file "$tmp_env" --file "$tmp_file" >/dev/null
python scripts/oa_media_sender.py --check --send --env-file "$tmp_env" --file "$tmp_file" >/dev/null
