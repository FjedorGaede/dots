#!/usr/bin/env bash
# Shelly detection for LanScannerService. Probes http://<ip>/shelly on every
# IP given as argument (in parallel) — every Shelly generation answers there
# without auth. Gen1: {type, mac, fw}; Gen2+: {id, model, gen, app, ver, name}.
# Output: one tab-separated row per Shelly: ip \t gen \t model \t fw \t name
# Usage: probe-shelly.sh 192.168.178.35 192.168.178.41 ...
for ip in "$@"; do
  (
    r=$(curl -s --connect-timeout 1 -m 2 "http://$ip/shelly" 2>/dev/null) || exit 0
    # must be JSON with a mac + (type|model) to count as a Shelly
    jq -e 'type=="object" and .mac and (.type or .model)' <<<"$r" >/dev/null 2>&1 || exit 0
    if jq -e '.gen' <<<"$r" >/dev/null 2>&1; then
      jq -r --arg ip "$ip" '[$ip, (.gen|tostring), (.app // .model), (.ver // ""), (.name // "")] | @tsv' <<<"$r"
    else
      # Gen1 keeps the user-given name in /settings
      name=$(curl -s --connect-timeout 1 -m 2 "http://$ip/settings" 2>/dev/null | jq -r '.name // ""' 2>/dev/null)
      jq -r --arg ip "$ip" --arg name "$name" \
        '[$ip, "1", .type, ((.fw // "") | sub("^.*/"; "") | sub("-.*$"; "")), $name] | @tsv' <<<"$r"
    fi
  ) &
  while (( $(jobs -r | wc -l) >= 64 )); do wait -n; done
done
wait
