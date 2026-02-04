#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

usage() {
  cat <<'EOF'
Usage:
  bash dev-up.sh [options] [-- <command...>]

Starts 3 local dev processes:
  1) Node proxy        (proxy/server.mjs)
  2) Media service     (media_service/server.mjs)
  3) Rust remote daemon (remote_daemon; connects to IRC)

Options:
  --check         Validate env + tools, then exit (no processes started)
  --no-proxy      Do not start proxy
  --no-media      Do not start media service
  --no-daemon     Do not start rust remote daemon
  -h, --help      Show help

Environment:
  Loads `.env` from repo root if present (shell-sourced).
  See `.env.example` for supported variables.

Examples:
  cp .env.example .env
  bash dev-up.sh
  bash dev-up.sh --no-daemon
  bash dev-up.sh -- godot4 --path .  # run a command with the same env
EOF
}

CHECK=0
NO_PROXY=0
NO_MEDIA=0
NO_DAEMON=0
CMD=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) CHECK=1; shift ;;
    --no-proxy) NO_PROXY=1; shift ;;
    --no-media) NO_MEDIA=1; shift ;;
    --no-daemon) NO_DAEMON=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; CMD=("$@"); break ;;
    *) echo "Unknown arg: $1" >&2; echo >&2; usage; exit 2 ;;
  esac
done

if [[ -f "$ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/.env"
  set +a
fi

PROXY_HOST="${OPENAGENTIC_PROXY_HOST:-127.0.0.1}"
PROXY_PORT="${OPENAGENTIC_PROXY_PORT:-8787}"
MEDIA_HOST="${OPENAGENTIC_MEDIA_HOST:-127.0.0.1}"
MEDIA_PORT="${OPENAGENTIC_MEDIA_PORT:-8788}"

export OPENAGENTIC_PROXY_BASE_URL="${OPENAGENTIC_PROXY_BASE_URL:-http://${PROXY_HOST}:${PROXY_PORT}/v1}"
export OPENAGENTIC_MEDIA_BASE_URL="${OPENAGENTIC_MEDIA_BASE_URL:-http://${MEDIA_HOST}:${MEDIA_PORT}}"

missing=0
need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    missing=1
  fi
}

if [[ "$NO_PROXY" -eq 0 ]]; then
  need_cmd node
  if [[ -z "${OPENAI_API_KEY:-}" ]]; then
    echo "Missing required env: OPENAI_API_KEY (needed by proxy)" >&2
    missing=1
  fi
fi

if [[ "$NO_MEDIA" -eq 0 ]]; then
  need_cmd node
  if [[ -z "${OPENAGENTIC_MEDIA_BEARER_TOKEN:-}" ]]; then
    echo "Missing required env: OPENAGENTIC_MEDIA_BEARER_TOKEN (needed by media service)" >&2
    missing=1
  fi
fi

if [[ "$NO_DAEMON" -eq 0 ]]; then
  need_cmd cargo
fi

if [[ "$CHECK" -eq 1 ]]; then
  if [[ "$missing" -ne 0 ]]; then
    echo >&2
    echo "Hint: copy `.env.example` to `.env` and fill required values." >&2
  fi
  exit "$missing"
fi

mkdir -p "$ROOT/.dev"
LOG_DIR="$ROOT/.dev/logs"
mkdir -p "$LOG_DIR"

pids=()

cleanup() {
  local pid
  for pid in "${pids[@]:-}"; do
    if kill -0 "$pid" >/dev/null 2>&1; then
      kill "$pid" >/dev/null 2>&1 || true
    fi
  done
}
trap cleanup EXIT INT TERM

echo "[dev-up] proxy: ${OPENAGENTIC_PROXY_BASE_URL}"
echo "[dev-up] media: ${OPENAGENTIC_MEDIA_BASE_URL}"

if [[ "$NO_PROXY" -eq 0 ]]; then
  echo "[dev-up] starting proxy..."
  (node "$ROOT/proxy/server.mjs" --host "$PROXY_HOST" --port "$PROXY_PORT") >"$LOG_DIR/proxy.log" 2>&1 &
  pids+=("$!")
  echo "[dev-up] proxy pid: ${pids[-1]} (log: .dev/logs/proxy.log)"
fi

if [[ "$NO_MEDIA" -eq 0 ]]; then
  echo "[dev-up] starting media service..."
  MEDIA_STORE_DIR="${OPENAGENTIC_MEDIA_STORE_DIR:-/tmp/oa-media}"
  (node "$ROOT/media_service/server.mjs" --host "$MEDIA_HOST" --port "$MEDIA_PORT" --store-dir "$MEDIA_STORE_DIR") >"$LOG_DIR/media.log" 2>&1 &
  pids+=("$!")
  echo "[dev-up] media pid: ${pids[-1]} (log: .dev/logs/media.log)"
fi

if [[ "$NO_DAEMON" -eq 0 ]]; then
  echo "[dev-up] starting rust remote daemon..."
  OA_HOST="${OA_IRC_HOST:-127.0.0.1}"
  OA_PORT="${OA_IRC_PORT:-6667}"

  daemon_args=(--host "$OA_HOST" --port "$OA_PORT")
  if [[ -n "${OA_IRC_PASSWORD:-}" ]]; then daemon_args+=(--password "$OA_IRC_PASSWORD"); fi
  if [[ -n "${OA_IRC_NICK:-}" ]]; then daemon_args+=(--nick "$OA_IRC_NICK"); fi
  if [[ -n "${OA_IRC_USER:-}" ]]; then daemon_args+=(--user "$OA_IRC_USER"); fi
  if [[ -n "${OA_IRC_REALNAME:-}" ]]; then daemon_args+=(--realname "$OA_IRC_REALNAME"); fi

  if [[ -n "${OA_REMOTE_POLL_SECONDS:-}" ]]; then daemon_args+=(--poll-seconds "$OA_REMOTE_POLL_SECONDS"); fi
  if [[ -n "${OA_REMOTE_INSTANCE:-}" ]]; then daemon_args+=(--instance "$OA_REMOTE_INSTANCE"); fi
  if [[ -n "${OA_REMOTE_DATA_HOME:-}" ]]; then daemon_args+=(--data-home "$OA_REMOTE_DATA_HOME"); fi
  if [[ -n "${OA_REMOTE_DEVICE_CODE:-}" ]]; then daemon_args+=(--device-code "$OA_REMOTE_DEVICE_CODE"); fi
  if [[ -n "${OA_REMOTE_BASH_TIMEOUT_SEC:-}" ]]; then daemon_args+=(--bash-timeout-sec "$OA_REMOTE_BASH_TIMEOUT_SEC"); fi

  if [[ "${OA_REMOTE_ENABLE_BASH:-0}" == "1" ]]; then daemon_args+=(--enable-bash); fi

  (cargo run --manifest-path "$ROOT/remote_daemon/Cargo.toml" -- "${daemon_args[@]}") >"$LOG_DIR/remote_daemon.log" 2>&1 &
  pids+=("$!")
  echo "[dev-up] remote daemon pid: ${pids[-1]} (log: .dev/logs/remote_daemon.log)"
fi

echo "[dev-up] started: ${#pids[@]} process(es). Ctrl-C to stop."

if [[ "${#CMD[@]}" -gt 0 ]]; then
  echo "[dev-up] running command: ${CMD[*]}"
  "${CMD[@]}"
  exit $?
fi

if [[ "${#pids[@]}" -eq 0 ]]; then
  echo "[dev-up] nothing to run (all services disabled)."
  exit 0
fi

wait -n "${pids[@]}"
