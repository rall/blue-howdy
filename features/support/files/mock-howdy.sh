#!/usr/bin/env bash
set -euo pipefail

# mode file: success | fail | delay
MODE="$(cat /etc/howdy/mock_mode 2>/dev/null || echo success)"

cmd="${1:-}"
if [[ $# -lt 1 || "$cmd" == "-h" || "$cmd" == "--help" ]]; then
  echo "Mock howdy: supports 'test' and 'version' (controlled by /etc/howdy/mock_mode)"
  exit 0
fi

if [[ "$cmd" == "version" ]]; then
  echo "Howdy 3.0.0-mock"
  exit 0
fi

if [[ "$cmd" == "test" ]]; then
  # Emulate upstream’s root requirement text so scripts don’t diverge
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "Please run this command as root:"
    echo
    echo "    sudo howdy test"
    exit 1
  fi

  case "$MODE" in
    success)
      echo "Identified face as mockuser"
      exit 0
      ;;
    delay)
      sleep 2
      echo "Identified face as mockuser (delayed)"
      exit 0
      ;;
    fail)
      echo "No face match found"
      exit 1
      ;;
    *)
      echo "Unknown mock mode: $MODE"
      exit 2
      ;;
  esac
fi

echo "Mock howdy: unsupported command '$cmd' in test image"
exit 0
