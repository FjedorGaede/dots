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

// Teams sends a reaction as summary "<Name> reacted to your message" with
// YOUR message as body (and the reactor's avatar) — no emoji. Shown as-is it
// reads as if they wrote your text. Returns the reactor's name, or "" when
// it isn't a reaction.
const reactionPatterns = [
    /^(.+?) reacted to your message$/,
    /^(.+?) hat auf (?:Ihre|deine) Nachricht reagiert$/,
];

function reactor(notification) {
    const summary = notification.summary.trim();
    for (let i = 0; i < reactionPatterns.length; i++) {
        const m = summary.match(reactionPatterns[i]);
        if (m) return m[1];
    }
    return "";
}
