pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Usage / limits of AI providers (Anthropic subscription windows, OpenRouter
// credits). All the work is in scripts/ai-usage.py (runnable by hand); it
// reads Pi's auth.json read-only. Shown in the Home menu (HomeUsage.qml).
//
// Each provider object is { ok: true, … } or { ok: false, error: "…" };
// `{}` until the first fetch finished.
Singleton {
    id: root

    property var anthropic: ({})
    property var openrouter: ({})
    // Provider names in auth.json that ai-usage.py has no usage code for
    property var unknown: []
    property bool loading: checkProc.running
    property double fetchedAt: 0

    // The Home menu calls this when it opens; skipped if data is fresher than 30s
    function refresh(force) {
        if (checkProc.running) return;
        if (!force && Date.now() - fetchedAt < 30000) return;
        checkProc.running = true;
    }

    Component.onCompleted: refresh(true)

    Timer {
        interval: 3 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.refresh(true)
    }

    Process {
        id: checkProc
        command: ["python3", "-I", Quickshell.shellPath("scripts/ai-usage.py")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.anthropic = d.anthropic ?? {};
                    root.openrouter = d.openrouter ?? {};
                    root.unknown = d.unknown ?? [];
                    root.fetchedAt = Date.now();
                } catch (e) {
                    // keep the last good data
                }
            }
        }
    }
}
