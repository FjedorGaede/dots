#!/usr/bin/env bash
# Theme adapter: pi (coding agent).
#
# pi themes are JSON files; pi hot-reloads the active one from
# $PI_CODING_AGENT_DIR/themes/<name>.json. We render a "wal" theme
# (settings.json selects it) from ~/.cache/wal/colors.json + the main accent.
# Tinted backgrounds (tool boxes, user messages) are blends over the wal
# background — the reason this is generated instead of using palette indices.
# The themes/ dir is a real dir (only files inside are stowed), so the
# generated file never lands in the repo.

set -euo pipefail

command -v pi >/dev/null 2>&1 || exit 0   # not installed — nothing to do

themes_dir="${PI_CODING_AGENT_DIR:-$HOME/.config/pi/agent}/themes"
mkdir -p "$themes_dir"

tmp="$(mktemp "$themes_dir/.wal.json.XXXXXX")"
jq --arg accent "$(cat "$HOME/.cache/wal/accent")" '
    def h2i: ascii_downcase | explode | map(if . >= 97 then . - 87 else . - 48 end) | .[0] * 16 + .[1];
    def rgb: ltrimstr("#") | [.[0:2], .[2:4], .[4:6]] | map(h2i);
    def i2h: [(. / 16 | floor), (. % 16)] | map(if . < 10 then . + 48 else . + 87 end) | implode;
    # mix(a; b; t) = a over b at opacity t
    def mix($a; $b; $t): [($a | rgb), ($b | rgb)] | transpose
        | map((.[0] * $t + .[1] * (1 - $t)) | round | i2h) | "#" + join("");
    def luma: rgb | .[0] * 299 + .[1] * 587 + .[2] * 114;

    .special.background as $bg | .special.foreground as $fg | .colors as $c |
    mix($fg; $bg; 0.65) as $muted |
    {
        name: "wal",
        appearance: (if ($bg | luma) >= 128000 then "light" else "dark" end),
        colors: {
            accent: $accent, border: mix($fg; $bg; 0.3), borderAccent: $accent,
            borderMuted: mix($fg; $bg; 0.2),
            success: $c.color2, error: $c.color1, warning: $c.color3,
            muted: $muted, dim: mix($fg; $bg; 0.5), text: "", thinkingText: $muted,

            selectedBg: mix($fg; $bg; 0.12),
            scrollbarTrack: mix($fg; $bg; 0.12), scrollbarThumb: mix($fg; $bg; 0.4),
            searchMatchBg: mix($c.color3; $bg; 0.3), searchMatchText: $fg,
            userMessageBg: mix($fg; $bg; 0.1), userMessageText: $fg,
            customMessageBg: mix($accent; $bg; 0.12), customMessageText: $fg,
            customMessageLabel: $accent,
            toolPendingBg: mix($fg; $bg; 0.05),
            toolSuccessBg: mix($c.color2; $bg; 0.12),
            toolErrorBg: mix($c.color1; $bg; 0.15),
            toolTitle: $accent, toolOutput: $fg,

            mdHeading: $accent, mdLink: $c.color6, mdLinkUrl: $muted,
            mdCode: $c.color6, mdCodeBlock: $fg, mdCodeBlockBorder: mix($fg; $bg; 0.3),
            mdQuote: $muted, mdQuoteBorder: $accent, mdHr: mix($fg; $bg; 0.2),
            mdListBullet: $accent,

            toolDiffAdded: $c.color2, toolDiffRemoved: $c.color1, toolDiffContext: $muted,

            syntaxComment: $muted, syntaxKeyword: $c.color5, syntaxFunction: $c.color2,
            syntaxVariable: $fg, syntaxString: $c.color3, syntaxNumber: $c.color4,
            syntaxType: $c.color6, syntaxOperator: $c.color5, syntaxPunctuation: $fg,

            thinkingOff: mix($fg; $bg; 0.4), thinkingMinimal: $c.color4,
            thinkingLow: $c.color6, thinkingMedium: $c.color2, thinkingHigh: $c.color3,
            thinkingXhigh: $c.color1, thinkingMax: $c.color9,

            bashMode: $c.color3
        }
    }
' "$HOME/.cache/wal/colors.json" > "$tmp"

# atomic swap — pi hot-reloads on change and must never see a half-written file
mv "$tmp" "$themes_dir/wal.json"
