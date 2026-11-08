pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

import qs.config

// USB flasher: write an ISO / image to a USB stick. UI in modules/flasher/
// (overview: modules/flasher/README.md). The write itself is
// modules/flasher/flash.sh under pkexec — it re-checks the target as root.
//
//   qs ipc call flasher open | close | toggle   (PanelService)
//   qs ipc call flash status
//
// Only USB disks that are removable or hotplug are offered (lsblk); the
// internal disks never show up.
Singleton {
    id: root

    // "idle" | "flashing" | "done" | "error"
    property string phase: "idle"
    readonly property bool busy: root.phase === "flashing"

    // Images found in ~/Downloads and ~ ({ path, name, size }), newest first
    property var images: []
    // USB sticks ({ path, label, size })
    property var drives: []

    property string image: ""     // chosen image path
    property string drive: ""     // chosen device path (/dev/sdX)

    readonly property var imageInfo: root.images.find(i => i.path === root.image) ?? null
    readonly property var driveInfo: root.drives.find(d => d.path === root.drive) ?? null
    readonly property bool fits: !!root.imageInfo && !!root.driveInfo
        && root.imageInfo.size <= root.driveInfo.size
    readonly property bool canFlash: root.phase !== "flashing" && root.fits

    property real written: 0      // bytes
    property string speed: ""     // "61.7 MB/s"
    property string error: ""
    readonly property real progress: root.imageInfo && root.imageInfo.size > 0
        ? Math.min(1, root.written / root.imageInfo.size) : 0

    function refresh() {
        if (!imagesProc.running) imagesProc.running = true;
        if (!drivesProc.running) drivesProc.running = true;
    }

    function flash() {
        if (!root.canFlash) return;
        root.written = 0;
        root.speed = "";
        root.error = "";
        root.phase = "flashing";
        root.baseSectors = -1;
        root.lastWritten = 0;
        // The polkit dialog is a normal window — our overlay would cover it.
        // Hide the menu until the write starts (or pkexec gives up)
        root.authPending = true;
        PanelService.close("flasher");
        flashProc.command = ["pkexec", Quickshell.shellPath("modules/flasher/flash.sh"),
                             root.image, root.drive];
        flashProc.running = true;
    }

    // Progress: the stick's "sectors written" counter (/sys/block/<dev>/stat,
    // field 7, 512-byte units) — readable without root. dd's own
    // status=progress does not reach us through pkexec. oflag=direct → the
    // counter follows the real writes (no page cache in between).
    // Waiting for the polkit password (menu hidden meanwhile, see flash())
    property bool authPending: false

    function authDone() {
        if (!root.authPending) return;
        root.authPending = false;
        PanelService.open("flasher");
    }

    property real baseSectors: -1
    property real lastWritten: 0

    Timer {
        interval: 1000
        repeat: true
        running: root.busy
        onTriggered: if (!statProc.running) statProc.running = true
    }

    Process {
        id: statProc
        command: ["cat", "/sys/block/" + root.drive.replace("/dev/", "") + "/stat"]
        stdout: StdioCollector {
            onStreamFinished: {
                const sectors = Number(this.text.trim().split(/\s+/)[6]);
                if (isNaN(sectors)) return;
                if (root.baseSectors < 0) { root.baseSectors = sectors; return; }
                const bytes = (sectors - root.baseSectors) * 512;
                root.speed = root.formatSize(Math.max(0, bytes - root.lastWritten)) + "/s";
                root.lastWritten = bytes;
                root.written = Math.min(bytes, root.imageInfo?.size ?? bytes);
                if (bytes > 0) root.authDone();   // writing → password was accepted
            }
        }
    }

    // Back to the picker after done / error
    function reset() {
        if (root.busy) return;
        root.phase = "idle";
        root.error = "";
    }

    function formatSize(bytes) {
        const units = ["B", "KB", "MB", "GB", "TB"];
        let i = 0;
        while (bytes >= 1000 && i < units.length - 1) { bytes /= 1000; i++; }
        return (i === 0 ? bytes : bytes.toFixed(1)) + " " + units[i];
    }

    // .iso / .img (also compressed images are NOT offered: dd would write them raw)
    Process {
        id: imagesProc
        command: ["sh", "-c",
            'find "$HOME/Downloads" "$HOME" -maxdepth 2 -type f \\( -iname "*.iso" -o -iname "*.img" \\) '
            + '-printf "%T@\\t%s\\t%p\\n" 2>/dev/null | sort -rn | awk -F "\\t" "!seen[\\$3]++"']
        stdout: StdioCollector {
            onStreamFinished: {
                root.images = this.text.split("\n").filter(l => l !== "").map(l => {
                    const [, size, path] = l.split("\t");
                    return { path: path, name: path.split("/").pop(), size: Number(size) };
                });
                if (!root.imageInfo) root.image = root.images[0]?.path ?? "";
            }
        }
    }

    Process {
        id: drivesProc
        command: ["lsblk", "-J", "-b", "-d", "-o", "PATH,SIZE,MODEL,VENDOR,TRAN,RM,HOTPLUG,TYPE"]
        stdout: StdioCollector {
            onStreamFinished: {
                let list = [];
                try {
                    list = JSON.parse(this.text).blockdevices
                        .filter(d => d.type === "disk" && d.tran === "usb" && (d.rm || d.hotplug) && d.size > 0)
                        .map(d => ({
                            path: d.path,
                            label: (d.model || d.vendor || "USB drive").trim(),
                            size: Number(d.size)
                        }));
                } catch (e) {}
                // Replace only on change: keeps the delegates (hover) stable
                if (JSON.stringify(list) !== JSON.stringify(root.drives)) root.drives = list;
                if (!root.driveInfo && !root.busy) root.drive = root.drives[0]?.path ?? "";
            }
        }
    }

    // Sticks come and go → poll while the menu is open
    Timer {
        interval: 2000
        repeat: true
        running: PanelService.isOpen("flasher") && !root.busy
        onTriggered: if (!drivesProc.running) drivesProc.running = true
    }

    Process {
        id: flashProc
        // Errors only (flash.sh "error: …", dd "dd: …"); progress comes from statProc
        stderr: SplitParser {
            onRead: data => {
                if (data.startsWith("error: ") || data.startsWith("dd: "))
                    root.error = data.replace(/^error: /, "");
            }
        }
        onExited: code => {
            if (code === 0) {
                root.written = root.imageInfo?.size ?? root.written;
                root.phase = "done";
                Apps.notify("USB stick ready", (root.imageInfo?.name ?? "Image") + " → "
                    + (root.driveInfo?.label ?? root.drive) + " — safe to remove");
            } else {
                // 126/127 = pkexec: dialog dismissed / not authorized
                if (root.error === "")
                    root.error = code === 126 || code === 127 ? "Authorization cancelled" : "dd failed (exit " + code + ")";
                root.phase = "error";
            }
            drivesProc.running = true;
            root.authDone();   // cancelled / failed before writing → show why
        }
    }

    // ── One-click install (docs/APPS.md) ──
    property bool installed: true   // optimistic: no install flash at startup
    readonly property bool installing: installProc.running
    readonly property var installCheckCommand:
        [Paths.dotsDir + "/packages/hyprland/install/usb-flasher/install.sh", "--check"]

    function checkInstalled() {
        if (!installCheck.running) installCheck.running = true;
    }

    function install() {
        if (installProc.running) return;
        installProc.command = Apps.floatingTerminalCommand(
            Paths.dotsCli + " install hyprland --only usb-flasher");
        installProc.running = true;
    }

    Process {
        id: installCheck
        running: true
        command: root.installCheckCommand
        onExited: code => root.installed = code === 0
    }

    Process {
        id: installProc
        onExited: postInstallCheck.running = true
    }

    Process {
        id: postInstallCheck
        command: root.installCheckCommand
        onExited: code => {
            root.installed = code === 0;
            if (!root.installed) return;
            Quickshell.execDetached(["sh", "-c", "sleep 1.5; qs ipc call flasher open"]);
            Quickshell.reload(false);
        }
    }

    IpcHandler {
        target: "flash"

        function status(): string {
            return root.phase + " installed=" + root.installed + " image=" + root.image
                + " drive=" + root.drive + " written=" + root.written + " error=" + root.error;
        }
    }
}
