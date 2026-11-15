import QtQuick

import '../../../lib/icons.js' as Icons
import qs.components
import qs.config
import qs.services

// System needs attention: stale (no completed -Syu for 7+ days), broken
// mirror, or reboot after a kernel update — hidden otherwise. Click runs the
// upgrade in a floating terminal (UpdatesService.act).
BarButton {
    visible: UpdatesService.needsAction

    icon: UpdatesService.mirrorBroken ? Icons.updates.mirror
        : UpdatesService.stale ? Icons.updates.pending
        : Icons.updates.reboot
    iconColor: UpdatesService.critical ? Theme.error : Theme.warning
    label: UpdatesService.stale ? String(UpdatesService.updates) : ""

    tooltipText: {
        const s = UpdatesService;
        const lines = [];
        if (s.mirrorBroken) lines.push("Mirror unreachable / outdated — click: rank mirrors + update");
        if (s.stale) lines.push(s.updates + " updates · last full upgrade "
            + (s.days < 0 ? "unknown" : s.days + " days ago") + " — click: sudo pacman -Syu");
        if (s.reboot) lines.push("Kernel updated — reboot pending");
        return lines.join("\n");
    }

    onClicked: UpdatesService.act()
}
