pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Scans the local network for devices using only built-in tools
// (ip, ping, getent, avahi-resolve): parallel ping sweep to populate the
// ARP table, then name resolution via DNS reverse lookup (the FritzBox
// publishes DHCP names there) with an mDNS fallback.
//
// Result: [{ ip, mac, online, name }] — online = answered a ping,
// everything else was still visible in the ARP table ("seen").
Singleton {
    id: root

    property var devices: []
    property bool scanning: false
    property real lastScanAt: 0

    function scan() {
        if (root.scanning) return;
        root.scanning = true;
        proc.running = true;
    }

    function parse(raw) {
        const out = [];
        for (const line of raw.split("\n")) {
            if (!line.trim()) continue;
            // tab-separated: ip \t mac \t online(1/0) \t name
            const f = line.split("\t");
            out.push({
                ip: f[0] ?? "",
                mac: f[1] ?? "",
                online: f[2] === "1",
                name: f[3] ?? ""
            });
        }
        root.devices = out;
        root.scanning = false;
        root.lastScanAt = Date.now();
    }

    Process {
        id: proc
        command: ["bash", "-c", root.scanScript]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
        onExited: root.scanning = false
    }

    // NB: "\${" is a literal "${" for bash — don't "fix" the backslashes.
    readonly property string scanScript: `
#!/usr/bin/env bash
tmp=\$(mktemp -d); trap 'rm -rf "\$tmp"' EXIT

# ── subnets to scan: global IPv4 /24+ networks, skipping bridges/containers/vpn ──
declare -A SUBNETS
while read -r iface addr mask; do
  [[ \$iface =~ ^(docker|virbr|br-|veth|tailscale|wg|lo|vmnet|vboxnet) ]] && continue
  [[ \$mask -lt 24 ]] && continue
  SUBNETS[\${addr%.*}]=1
done < <(ip -4 -o addr show scope global | awk '{split(\$4,a,"/"); print \$2, a[1], a[2]}')

# ── this laptop itself (own interfaces count as devices too) ──
declare -A MAC SELF
while read -r iface addr; do
  mac=\$(cat "/sys/class/net/\$iface/address" 2>/dev/null)
  if [[ -n \$mac ]]; then MAC[\$addr]=\$mac; SELF[\$addr]=1; fi
done < <(ip -4 -o addr show scope global | awk '{split(\$4,a,"/"); print \$2, a[1]}')

# ── parallel ping sweep to populate the ARP table ──
for prefix in "\${!SUBNETS[@]}"; do
  for i in \$(seq 1 254); do
    (ping -c1 -W1 -n "\$prefix.\$i" >/dev/null 2>&1) &
    while (( \$(jobs -r | wc -l) >= 128 )); do wait -n; done
  done
done
wait

# ── collect ip + mac from ARP (IPv4 only, skip failed/incomplete entries) ──
while read -r ip mac; do
  [[ -n \$mac && \$mac != 00:00:00:00:00:00 ]] && MAC[\$ip]=\$mac
done < <(ip -o neigh show | awk '\$1 ~ /^[0-9]+\./ && \$2=="dev" && \$4=="lladdr" {print \$1, \$5}')

# ── second round: confirm liveness for detected hosts ──
printf '%s\n' "\${!MAC[@]}" | xargs -P 64 -I{} sh -c "ping -c1 -W1 -n {} >/dev/null 2>&1 && touch '\$tmp/{}'"

# ── names: DNS reverse (FritzBox knows DHCP names) + mDNS fallback, parallel ──
for ip in "\${!MAC[@]}"; do
  (
    n=\$(timeout 3 getent hosts "\$ip" 2>/dev/null | awk '{print \$2; exit}')
    if [[ -z \$n ]]; then
      n=\$(timeout 2 avahi-resolve -a "\$ip" 2>/dev/null | awk '{print \$2; exit}')
      [[ \$n == *.local ]] || n=""
    fi
    printf '%s\t%s\n' "\$ip" "\$n"
  ) &
done > "\$tmp/names"
wait
declare -A NAME
while IFS=\$'\\t' read -r ip n; do [[ -n \$n ]] && NAME[\$ip]=\$n; done < "\$tmp/names"

# ── emit tab-separated rows: ip \t mac \t online \t name ──
for ip in \$(printf '%s\n' "\${!MAC[@]}" | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n); do
  [[ -f \$tmp/\$ip ]] && online=1 || online=0
  printf '%s\t%s\t%s\t%s\n' "\$ip" "\${MAC[\$ip]}" "\$online" "\${NAME[\$ip]}"
done
`
}
