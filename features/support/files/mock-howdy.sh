#!/usr/bin/env bash
set -euo pipefail

MODE="$(cat /run/mock-howdy-mode 2>/dev/null || echo success)"
cmd="${1:-}"

log() { logger -t mock-howdy -- "$*"; }

if [[ "$cmd" == "test" ]]; then
  case "$MODE" in
    success) log "ok";  exit 0 ;;
    fail)    log "fail"; exit 1 ;;
    *)       log "bad-mode:$MODE"; exit 2 ;;
  esac
fi

exit 0
