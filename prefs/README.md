# prefs — app settings that can't be stowed

Some apps keep their settings in a file they **rewrite themselves**, e.g.
Vivaldi's `~/.config/vivaldi/Default/Preferences`. Stow can't manage that:
the app replaces the symlink with a real file on its next save. And the file
is full of things that don't belong in git (sync tokens, device IDs, per-site
data, counters).

So instead of the whole file, the repo keeps **only the settings we choose**
and `dots prefs` merges them into the live file.

## Why Vivaldi needs this

Vivaldi Sync covers bookmarks, passwords, history, tabs, extensions, notes
and *some* settings. It does **not** sync keyboard shortcuts, the theme,
layouts or the panel setup — those exist only on the machine where you made
them.

What Vivaldi sync *does* cover lives under `account_values` in Preferences
(most tab behavior incl. the **tab switcher** — cycle order, visual switch —
address bar, mouse gesture on/off, startup, downloads, ...). Those need no
help from here, as long as **Settings → Sync → "Settings"** is enabled on
every machine. A synced setting that doesn't show up on another machine was
probably set before sync was on there: toggle it once to upload it.

The authoritative list of what Vivaldi syncs ships with Vivaldi:

```
jq -r '.syncable | keys[]' /opt/vivaldi/resources/vivaldi/prefs_definitions.json
```

## What is stored

`prefs/vivaldi/app.sh` lists the keys (dotted JSON paths into Preferences),
grouped:

| Group | What |
|---|---|
| Keyboard | shortcuts + mouse gesture mappings (`vivaldi.actions`), which shortcuts win over websites, ctrl+f toggles the find bar |
| Theme | custom themes, active theme, private-window theme, theme schedule, accent + highlight color, density, dim unfocused windows, narrow scrollbars |
| UI layout | saved layouts, all toolbars, panels (list, position, web panels), tab bar + address bar position, status bar, auto-hide, menu, native window decoration |
| Tab behavior | double-click action, stacking mode + editor, drag&drop tiling, pinned-tab rules (the rest of tab behavior is synced by Vivaldi) |
| Address bar | dropdown contents (bookmarks, calculator, search history, size), search suggestions, search field width |
| Reader + start page | reader view style/controls, speed dial navigation/columns/size, dashboard on/off + columns |

Deliberately **not** stored: start page widgets (`vivaldi.dashboard.widgets`
— the weather widget holds your city), sticky notes (note text), workspaces
(IDs differ per machine, link rules list sites), the sync account, and
anything machine-specific. Custom theme background images you
uploaded yourself may not carry over (colors and settings do).

**The repo is public.** Everything in `prefs.json` is visible on GitHub.
`dots prefs capture` therefore lists every URL, email address and home path
it finds in the captured settings (e.g. a web panel that opens a private
URL) — check that list and the git diff before pushing. To
keep something out, remove it in Vivaldi or drop its key from `app.sh`.

Their values live in `prefs/vivaldi/prefs.json` (sorted, pretty-printed, so
git diffs stay readable). Only the profile `Default` is handled.

Each listed key is **owned by the repo as a whole**: applying replaces that
key's entire content; everything else in Preferences is never touched.

## Daily use

```
dots prefs                    # = dots prefs diff: live vs. repo
dots prefs capture            # live → repo, then commit via dots git
dots prefs apply              # repo → live (shows diff, asks)
dots update                   # pull — applies changed prefs automatically
```

All commands take app names (`dots prefs diff vivaldi`); none = every app in
`prefs/`.

**Changed a shortcut?** `dots prefs capture` → commit + push in `dots git`.
The other machines get it with their next `dots update`.

**New machine:** start Vivaldi once (so it creates its profile), then
`dots prefs apply`.

## When Vivaldi is running

Vivaldi writes Preferences when it quits, so changing the file while it runs
is pointless — it would be overwritten. Whenever something has to be written:

- **`dots update`** asks *"vivaldi is running — close it, apply, and reopen
  it?"*. Yes → Vivaldi is closed, the settings are applied, Vivaldi is
  started again. No (or no terminal, e.g. run from a script) → nothing
  written, hint to run `dots prefs apply vivaldi` later.
- **`dots prefs apply`** shows the diff and asks once; the question says that
  Vivaldi will be closed and reopened. `--yes` skips the question and closes
  without asking.

Closing is a normal quit (SIGTERM to the main process — Chromium treats it
exactly like closing the window): the session is saved, nothing counts as a
crash. Whether your tabs come back is Vivaldi's own setting: **Settings →
General → Startup with → Last Session**. Reopening runs `launch` from
`app.sh` (`vivaldi-stable`).

`dots prefs capture` works while Vivaldi runs, but Vivaldi saves changes
with a few seconds' delay — capture again if a change is missing.

## Conflicts

A conflict means: the repo has new settings **and** this machine has changes
that were never captured. They are resolved **per setting** — for shortcuts
that's one command's key list:

- changed on only one side → that side wins, automatically
- changed on both sides to the same value → fine
- **the same setting changed differently on both sides** → real conflict,
  you decide

Where it happens:

| Situation | What happens |
|---|---|
| `dots update` pulls new prefs, Vivaldi has uncaptured changes | Merged (after closing Vivaldi, so its last changes are included). Result goes into Vivaldi **and** into `prefs.json` → commit it via `dots git`. |
| …and the same setting changed on both sides | Nothing written. `dots prefs diff`, then `capture` (keep this machine's) or `apply` (take the repo's). |
| Both machines committed captures, git histories diverged | The git merge driver (`.gitattributes` → `dots prefs merge-driver`) merges per setting, so git sees no conflict. Same setting on both sides → normal conflict markers, resolve in lazygit. |
| `dots prefs apply` and Vivaldi has uncaptured changes | The diff shows them; you confirm before they are overwritten. |

Safety nets: every write first copies the live file to
`~/.dotfiles-backup/prefs-<app>.<timestamp>/`. To undo: close the app and copy
it back.

## Adding settings or apps

**More Vivaldi settings:** add the key to `keys=(...)` in
`prefs/vivaldi/app.sh`, then `dots prefs capture vivaldi`. Find keys with:

```
jq '.vivaldi | keys' ~/.config/vivaldi/Default/Preferences
```

Rules: never add keys Vivaldi syncs itself (`account_values` — both would
fight over them), never `vivaldi.vivaldi_account` (login token), nothing
machine-specific (`startup`, `sessions`, counters).

**Another app** with the same problem: create `prefs/<app>/app.sh`:

```bash
target="$HOME/.config/<app>/settings.json"   # the live JSON file
process="<app>"                               # process name (pgrep -x)
launch=(<app>)                                # command to reopen it (optional)
keys=(some.key other.key)                     # dotted paths the repo owns
```

then `dots prefs capture <app>`. No code changes — the directory is the
registry.

## How it works (for changing the code)

Code: `dots-cli/lib/prefs.sh` (commands), helpers in
`dots-cli/lib/common.sh` (`prefs_*`), the `dots update` part in
`dots-cli/lib/update.sh` (`update_prefs`). Details in `dots-cli/AGENTS.md`.
