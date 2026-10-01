.pragma library
.import Quickshell as QS

// Icon for a notification (toast + history). "" → caller shows the bell glyph.
function iconSource(notification) {
    // Prefer the attached image — chat apps send the sender's avatar/picture
    // here (e.g. Telegram)
    if (notification.image !== "") return notification.image;

    const icon = notification.appIcon;
    if (icon === "") return "";
    if (icon.startsWith("/") || icon.startsWith("file:")) return icon;
    return QS.Quickshell.iconPath(icon, true); // "" when not found
}
