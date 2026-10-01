#!/usr/bin/env bash
# setup: calendar — run via 'dots setup calendar'
#
# Connects Google accounts to the quickshell calendar. The OAuth client and
# tokens are secrets, so they never live in this repo — every machine connects
# once. `setup.sh status` only reports; without an argument it connects
# (OAuth client if missing, then a Google login) via 'dots calendar'.
set -euo pipefail

DATA="$HOME/.local/share/quickshell"
DOTS="${DOTS:-dots}"

# Logging out the last account leaves "{}" → count accounts, not bytes
accounts="$(python3 -c 'import json, sys; print(len(json.load(open(sys.argv[1]))))' \
    "$DATA/google-tokens.json" 2>/dev/null || echo 0)"

if [ "${1:-}" = "status" ]; then
    if [ "$accounts" -gt 0 ]; then
        echo "connected ($accounts Google account$([ "$accounts" -gt 1 ] && echo s))"
        exit 0
    fi
    echo "not connected"
    exit 1
fi

if [ ! -f "$DATA/google-client.json" ]; then
    echo "first the OAuth client: download the Desktop OAuth client JSON (Cloud console →"
    echo "  Google Auth Platform → Clients → Download JSON) into ~/Downloads, then press enter"
    read -r _
    "$DOTS" calendar client
fi

"$DOTS" calendar login
