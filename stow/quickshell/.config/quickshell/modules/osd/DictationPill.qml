import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

import '../../lib/icons.js' as Icons
import qs.components
import qs.config
import qs.services

// Dictation pill (DictationService): bottom center while whispy records /
// transcribes, then a check (inserted) or an X (not taken). Sits below the OSD (bottom: 100).
// Recording = an equalizer that opens from the center line, middle bars
// tallest; still while silent (whispy only publishes loudness, so the spread
// over the bars is shape, not a real spectrum).
//
// Always mapped with a fixed size, like Toasts: mapping/unmapping a layer
// surface churns focus and dismisses popup grabs (docs/GOTCHAS.md). Fully
// click-through (empty mask) and never takes keyboard focus — dictation types
// into whatever is focused, so stealing focus would send the text here.
PanelWindow {
    id: root

    readonly property int pillHeight: 44
    readonly property int padding: 16
    readonly property int barCount: 9
    readonly property int barMax: 26
    // One width for every state: the pill must not shrink when the bars give way
    // to the three dots or a check (bars + spacing + padding)
    readonly property int pillWidth: barCount * 4 + (barCount - 1) * 3 + padding * 2
    // Resting line while silent: all bars the same (the middle only grows
    // taller while you speak, via shape())
    readonly property int barRest: 4
    // Loudness in dB above the learned noise floor: gateDb of headroom stays
    // flat, rangeDb more fills the bars. Measured on the internal mic (30 s of
    // silence): mostly -45…-38 dB, short bumps (breath, chair) to ~-26 dB;
    // speech ~-25…-10 dB. Lower gateDb = more sensitive.
    readonly property real gateDb: 10
    readonly property real rangeDb: 18

    // Last non-idle state: the content stays put while the pill fades out
    property string view: "recording"
    readonly property bool shown: DictationService.active

    Connections {
        target: DictationService
        function onStateChanged() {
            // Every recording starts flat — also after a cancel or a dropped
            // (too short) clip, where the view never left "recording"
            if (DictationService.state !== "transcribing") root.resetMeter();
            if (DictationService.state === "idle") return;
            root.view = DictationService.state;
        }
    }

    exclusiveZone: 0
    anchors.bottom: true
    margins.bottom: 40
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell-dictation"

    color: "transparent"
    implicitWidth: 400
    implicitHeight: pillHeight
    mask: Region {}

    // ── Equalizer: one loudness value, spread over the bars by a fixed shape
    //    (middle tallest) with a little randomness per bar while you speak.
    //    Each bar has its own rise/fall speed, nothing overshoots — the fall is
    //    a straight settle back to the line. Silence = a still, flat line. ──
    property var bars: new Array(barCount).fill(0)
    // Learned noise floor — kept across recordings, so a new one reacts right
    // away instead of relearning the room. Starts at the measured quiet room.
    property real noiseDb: -42
    // Start artefacts are filtered by value, not by time (see below): holding
    // the meter still for a while made the bars miss the first words — only a
    // clipped start (full scale, falling off) is bogus, everything else is you.
    property bool settling: false
    property real lastRms: 0

    // 0..1 for the bar at index i (middle 1, edges ~0.45)
    function shape(i) { return 0.45 + 0.55 * Math.sin(Math.PI * (i + 0.5) / root.barCount); }

    function resetMeter() {
        root.bars = new Array(root.barCount).fill(0);
        root.settling = false;
    }

    Timer {
        interval: 40
        repeat: true
        running: root.shown && root.view === "recording"
        onTriggered: {
            const rms = DictationService.rms;
            if (rms < 1e-4) return;                    // whispy's placeholder
            if (rms > 0.9) { root.settling = true; root.lastRms = rms; return; }
            if (root.settling) {
                // while a clipped start is still falling, ignore it; the first
                // rise is the voice starting
                if (rms <= root.lastRms * 1.05) { root.lastRms = rms; return; }
                root.settling = false;
            }
            const db = 20 * Math.log10(rms);
            const level = Math.max(0, Math.min(1,
                (db - root.noiseDb - root.gateDb) / root.rangeDb));
            // Noise floor: follows quieter moments down quickly. It only creeps
            // up while it's quiet — while you speak it stays put, so a long
            // sentence doesn't slowly desensitize the meter.
            if (db < root.noiseDb) root.noiseDb += (db - root.noiseDb) * 0.3;
            else if (level <= 0.1) root.noiseDb += 0.02;
            root.bars = root.bars.map((v, i) => {
                const target = level * root.shape(i) * (0.7 + 0.3 * Math.random());
                // per-bar speeds: rise 0.75–0.95, fall 0.3–0.45 of the gap per tick
                const k = target > v ? 0.75 + 0.2 * ((i * 3) % 5) / 4
                                     : 0.3 + 0.15 * ((i * 2) % 5) / 4;
                const next = v + (target - v) * k;
                return Math.abs(next - target) < 0.01 ? target : next;
            });
        }
    }

    Rectangle {
        id: pill
        anchors.centerIn: parent
        height: root.pillHeight
        width: root.pillWidth
        radius: Theme.radius.lg
        color: Theme.background
        // Floats over windows of the same background color (terminals) → edge
        border.width: 1
        border.color: Theme.subdued

        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.9
        Behavior on opacity { NumberAnimation { duration: Theme.anim.slow } }
        Behavior on scale { NumberAnimation { duration: Theme.anim.slow; easing.type: Easing.OutCubic } }

        RowLayout {
            id: content
            anchors.centerIn: parent
            spacing: 12

            Row {
                visible: root.view === "recording"
                spacing: 3
                Layout.preferredHeight: root.barMax

                Repeater {
                    model: root.barCount
                    Rectangle {
                        required property int index
                        // grows from the center line up and down
                        anchors.verticalCenter: parent.verticalCenter
                        width: 4
                        radius: 2
                        height: root.barRest + (root.barMax - root.barRest) * root.bars[index]
                        color: Theme.foreground
                    }
                }
            }

            // Transcribing: three solid dots, one after the other grows
            Row {
                id: dots
                visible: root.view === "transcribing"
                spacing: 5
                Layout.preferredHeight: root.barMax
                property int active: 0

                Timer {
                    interval: 220
                    repeat: true
                    running: dots.visible && root.shown
                    onTriggered: dots.active = (dots.active + 1) % 3
                }

                Repeater {
                    model: 3
                    Rectangle {
                        required property int index
                        anchors.verticalCenter: parent.verticalCenter
                        width: 6
                        height: 6
                        radius: 3
                        color: Theme.foreground
                        scale: dots.active === index ? 1.5 : 1
                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
                    }
                }
            }

            // Done = check, not taken (too quiet / unclear / dropped) = an X.
            // whispy's error text stays in DictationService.errorMessage —
            // it only made the pill long.
            StyledText {
                visible: root.view === "success" || root.view === "error"
                text: root.view === "success" ? Icons.dictation.done : Icons.dictation.rejected
                color: root.view === "success" ? Theme.success : Theme.error
                font.pixelSize: Theme.fontSize.icon
                // Fixed box: the glyphs have different advance widths
                Layout.preferredWidth: 22
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
