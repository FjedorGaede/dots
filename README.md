# dots

My dotfiles for CachyOS + Hyprland: packages, configs, theming and the `dots`
CLI. Built on bash + GNU stow + gum.

## New machine

1. Install CachyOS without a desktop, log in on the TTY (WiFi: `nmtui`).
2. Run:
   ```
   bash <(curl -fsSL https://dots.fjedor.de/bootstrap.sh)
   ```
3. Reboot.

Afterwards:

- SSH key: `ssh-keygen -t ed25519` → add at github.com/settings/keys, then
  `git -C ~/dots remote set-url origin git@github.com:FjedorGaede/dots.git`
- `gh auth login`
- `sudo hostnamectl set-hostname <name>`
- `dots setup` (calendar login)

## The CLI

```
dots install [category] [--pick]   install packages + install scripts
dots add <pkg> [--aur]             install + track a package (auto-commit)
dots remove                        untrack a package
dots stow [component]              link configs into $HOME
dots setup                         per-machine steps (logins)
dots theme [name]                  apply a colorscheme
dots edit                          edit the configs
dots git                           lazygit in the repo
```

`dots help` shows everything.

## Layout

```
packages/<category>/   packages.txt + optional install/<name>/install.sh
setup/<name>/          per-machine steps for `dots setup`
stow/<component>/      the configs
dots-cli/              the CLI (internals: dots-cli/AGENTS.md)
```
