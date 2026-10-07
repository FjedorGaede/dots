import QtQuick

import '../../../lib/icons.js' as Icons
import qs.components
import qs.services
import qs.modules.panels

// Note: Muted and audio level on 0 is not the same. You can have your Audio Level to 50% and still mute it

BarButton {
    id: sound

    property int currentVolume: AudioService.volume
    property bool isMuted: AudioService.muted

    function getIcon() {
        return Icons.volumeIcon(currentVolume, isMuted);
    }

    icon: sound.getIcon()
    tooltipText: sound.currentVolume + "%"
    onClicked: PanelService.toggle("audio", audioPanel.screenName)

    AudioPanel {
        id: audioPanel
        anchorItem: sound
    }
}
