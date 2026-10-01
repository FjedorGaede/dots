import QtQuick

import qs.config

// Text with the shell's defaults (nerd font, foreground, 14px). Every Text in
// the shell uses Theme.fontFamily; plain `Text` + explicit font.family is
// only used where the default size must stay the system default (Tooltip)
// or the element is a primitive with its own sizing (SectionHeader, …).
Text {
    color: Theme.foreground
    // NB: font.family is REQUIRED — nerd glyphs are private-use
    // codepoints; without it Qt falls back to a random font that
    // happens to cover them (rendered as unrelated icons)
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize.lg
}
