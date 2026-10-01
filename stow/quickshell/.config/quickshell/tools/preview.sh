#!/usr/bin/env bash
# Dev helper for the refactor preview instance (docs/REFACTOR.md §11).
#   preview.sh restart   – (re)start the preview instance (needed for new singletons)
#   preview.sh log       – startup log of the current preview instance (warnings/errors)
#   preview.sh check     – restart + print WARN/ERROR lines + run bar-diff
set -u
P="$(cd "$(dirname "$0")/.." && pwd)"

restart() {
  qs kill -p "$P" >/dev/null 2>&1
  sleep 0.5
  QS_PREVIEW=1 qs -p "$P" -d >/dev/null 2>&1
  sleep 3
}

case "${1:-check}" in
  restart) restart ;;
  log)     qs log -p "$P" 2>&1 ;;
  check)
    restart
    echo "── preview WARN/ERROR (startup) ──"
    qs log -p "$P" 2>&1 | grep -E "WARN|ERROR|CRIT" \
      | grep -v "Could not register notification server\|Registration will be attempted again" \
      || echo "(none)"
    echo "── bar diff (live y=0 vs preview y=30) ──"
    python3 "$P/tools/bar-diff.py"
    ;;
esac
