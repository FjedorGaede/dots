# Vivaldi: settings its own sync doesn't cover. Keep keys out of here that
# Vivaldi sync handles (Vivaldi's "syncable" list in
# /opt/vivaldi/resources/vivaldi/prefs_definitions.json; synced values sit under
# account_values in Preferences) — both would fight over them. That's why e.g.
# the tab switcher (vivaldi.tabs.cycle_by_recent_order, visual_switch) is not here.
# Never add vivaldi.vivaldi_account (sync login token). The repo is PUBLIC —
# nothing personal (locations, notes, private URLs).
target="$HOME/.config/vivaldi/Default/Preferences"
process="vivaldi-bin"
launch=(vivaldi-stable)
keys=(
    # keyboard
    vivaldi.actions                                   # keyboard shortcuts + mouse gesture mappings
    vivaldi.keyboard.shortcuts.browser_priority_list  # shortcuts that win over websites
    vivaldi.webpages.find_shortcut_is_a_toggle        # ctrl+f also closes the find bar

    # theme
    vivaldi.themes.user                   # custom themes (self-uploaded background images may not carry over)
    vivaldi.themes.current
    vivaldi.themes.current_private
    vivaldi.themes.current_buttons
    vivaldi.themes.prefer_custom_buttons
    vivaldi.theme.private_window
    vivaldi.theme.schedule                # theme schedule (time / OS based)
    vivaldi.theme.dim_blurred             # dim unfocused windows
    vivaldi.theme.simple_scrollbar
    vivaldi.system.accent_color
    vivaldi.system.highlight_color
    vivaldi.appearance.density
    vivaldi.appearance.force_dark_mode_theme

    # UI layout
    vivaldi.layouts                       # saved layouts
    vivaldi.toolbars                      # every toolbar (toolbar editor)
    vivaldi.panel_editor
    vivaldi.panels.elements
    vivaldi.panels.position
    vivaldi.panels.web                    # web panels (and extension panels)
    vivaldi.tabs.bar.position             # tab bar top / left / ...
    vivaldi.address_bar.position
    vivaldi.address_bar.visible
    vivaldi.status_bar
    vivaldi.auto_hide
    vivaldi.menu
    vivaldi.windows.use_native_decoration

    # tab behavior (the part Vivaldi sync skips)
    vivaldi.tabs.double_click
    vivaldi.tabs.stacking.mode
    vivaldi.tabs.stacking.auto_editor
    vivaldi.tabs.tiling.drag_and_drop
    vivaldi.tabs.restrict_pinned_tabs
    vivaldi.tabs.close_pinned_in_stack

    # address bar dropdown + search field
    vivaldi.address_bar.omnibox.bookmarks
    vivaldi.address_bar.omnibox.bookmarks_boosted
    vivaldi.address_bar.omnibox.show_vivaldi_calculator
    vivaldi.address_bar.omnibox.show_typed_history_button
    vivaldi.address_bar.omnibox.search_history_enable
    vivaldi.address_bar.omnibox.dropdown_size
    vivaldi.address_bar.search.direct_match_boosted
    vivaldi.address_bar.search.always_show_dropdown_badge
    vivaldi.address_bar.search.field_width
    vivaldi.address_bar.search.suggest_enabled
    vivaldi.address_bar.search.hidden_direct_match_providers
    vivaldi.address_bar.show_pwa_install

    # reader view + start page
    vivaldi.webpages.reader
    vivaldi.startpage.navigation
    vivaldi.startpage.speed_dial.columns
    vivaldi.startpage.speed_dial.size

    # start page widgets — never sticky_notes (note text). widgets is off: the
    # weather widget stores your city (public repo)
    vivaldi.dashboard.enabled
    vivaldi.dashboard.columns
    vivaldi.dashboard.column_limit
    vivaldi.dashboard.top_sites_hide_suggestions
)
# Deliberately not stored (public repo / machine-specific):
#   vivaldi.dashboard.widgets       weather widget holds your city
#   vivaldi.dashboard.sticky_notes  note text
#   vivaldi.workspaces.*            workspace IDs differ per machine; link rules leak sites
