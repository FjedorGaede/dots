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

    // Shelly devices, found by probing http://<ip>/shelly after each scan:
    // [{ ip, gen, model, fw, name }] keyed by ip
    property var shellies: ({})
    property bool probingShelly: false

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
        root.probeShelly();
    }

    function probeShelly() {
        if (root.probingShelly) return;
        const ips = root.devices.filter(d => d.online).map(d => d.ip);
        if (ips.length === 0) return;
        root.probingShelly = true;
        shellyProc.command = ["bash", Quickshell.shellPath("scripts/probe-shelly.sh")].concat(ips);
        shellyProc.running = true;
    }

    function parseShelly(raw) {
        const out = {};
        for (const line of raw.split("\n")) {
            if (!line.trim()) continue;
            // tab-separated: ip \t gen \t model \t fw \t name
            const f = line.split("\t");
            out[f[0]] = { ip: f[0], gen: f[1] ?? "", model: f[2] ?? "", fw: f[3] ?? "", name: f[4] ?? "" };
        }
        root.shellies = out;
        root.probingShelly = false;
    }

    Process {
        id: proc
        // The scan itself lives in scripts/scan-lan.sh (runnable by hand)
        command: ["bash", Quickshell.shellPath("scripts/scan-lan.sh")]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
        onExited: root.scanning = false
    }

    Process {
        id: shellyProc
        stdout: StdioCollector {
            onStreamFinished: root.parseShelly(text)
        }
        onExited: root.probingShelly = false
    }
}
