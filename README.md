# dots

My dotfiles for CachyOS + Hyprland: packages, configs, theming and the `dots`
CLI. Built on bash + GNU stow + gum.

## New machine

1. Install CachyOS without a desktop, log in on the TTY (WiFi: `nmtui`).
2. Run (fish — CachyOS's default shell):
   ```
   bash (curl -fsSL https://dots.fjedor.de/bootstrap.sh | psub)
   ```
   or from bash/zsh:
   ```
   bash <(curl -fsSL https://dots.fjedor.de/bootstrap.sh)
   ```
   It asks everything up front (git name/email, which optional categories and
   what from them), sets up git + an ssh key, then runs unattended.
3. Reboot.

Afterwards, `dots setup` shows the open per-machine steps and runs them:

- `github` — gh login (browser / device code) + upload the ssh key
- `dots-remote` — switch `~/dots` origin to ssh
- `calendar` — Google calendar login

## The CLI

```
dots install [category] [--pick]   install packages + install scripts
dots add <pkg> [--aur]             install + track a package (auto-commit)
dots remove                        untrack a package
dots stow [component]              link configs into $HOME
dots setup [name]                  per-machine steps (git, ssh, github, ...)
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
