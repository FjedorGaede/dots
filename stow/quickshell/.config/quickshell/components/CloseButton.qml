import QtQuick

// ✕ button (notification toasts + history)
GhostButton {
    property int size: 36
    property int glyphSize: 15

    icon: "✕"
    iconSize: glyphSize
    rowContent: false
    implicitWidth: size
    implicitHeight: size
}
