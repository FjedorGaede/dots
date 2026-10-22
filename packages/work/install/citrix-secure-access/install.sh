#!/usr/bin/env bash
# install: citrix-secure-access (category: work)
# Runs on 'dots install work' after the category's packages are installed.
# MUST be idempotent — safe to run again on every install.
#
# Citrix Secure Access client (SPA / NetScaler Gateway). Citrix only ships an
# Ubuntu .deb behind a login, so it can't be tracked as a package: this
# repackages ~/Downloads/nsginstaller64.deb as the Arch package
# citrix-secure-access, installs it with its dependencies (gpgme-1 from the
# AUR for libgpgme.so.11, webkit2gtk-4.1 and libxml2-legacy for
# libxml2.so.2 via pacman) and enables the
# nsgverctl service. Nothing is installed while the .deb is missing — it
# then only prints the download link. The .deb is proprietary: never commit it.
#
# Usage after install: log in at the company Citrix URL in the browser, allow
# the citrixsso:// link. Logs: ~/.citrix/nssslvpn.txt, journalctl -u nsgverctl
#
# DNS: the client resolves company names by intercepting DNS queries — IPv4
# only. Queries to an IPv6 DNS server (e.g. announced by the home router) slip
# past it and return public IPs, which the company's allowlists then block.
# So this also installs a NetworkManager dispatcher hook that sets
# ipv6.ignore-auto-dns=yes on every wifi/ethernet profile when it comes up
# (existing profiles are switched right here). IPv6 itself keeps working.
# The client also flushes the systemd-resolved cache on connect (stale "not
# found" answers from before the tunnel) — as the user, which polkit denies;
# a polkit rule lets wheel members flush-caches (nothing else).
#
# Uninstall: sudo systemctl disable --now nsgverctl
#            sudo pacman -Rns citrix-secure-access   (also removes gpgme-1)
#            sudo rm /etc/NetworkManager/dispatcher.d/90-ipv4-dns-only
#            sudo rm /etc/polkit-1/rules.d/50-resolved-flush-caches.rules
#            (profiles keep ipv6.ignore-auto-dns=yes — per profile:
#             nmcli connection modify <name> ipv6.ignore-auto-dns no)
set -euo pipefail

DEB="${CITRIX_DEB:-$HOME/Downloads/nsginstaller64.deb}"
PKGNAME=citrix-secure-access
PKGREL=3   # bump when the packaging below changes, so installs get redone
BUILD_DIR="$HOME/.cache/citrix-secure-access-build"
DOWNLOAD_URL='https://www.citrix.com/downloads/citrix-secure-access/plug-ins/Citrix-Gateway-VPN-EPA-Clients-Ubuntu.html'

# SHA-256 of releases verified against the Citrix download page
declare -A KNOWN_SHA256=(
    [25.8.2]=56d3095495c6847738404a6f076e43484887675be4776ea73aa6ad11472c09b3
)

DNS_HOOK=/etc/NetworkManager/dispatcher.d/90-ipv4-dns-only
DNS_HOOK_CONTENT='#!/bin/sh
# Installed by dots (packages/work/install/citrix-secure-access) — see there.
# Citrix Secure Access only intercepts DNS over IPv4: ignore IPv6 DNS servers
# on every wifi/ethernet profile, once, when it first comes up.
[ "$2" = up ] && [ -n "$CONNECTION_UUID" ] || exit 0
case "$(nmcli -g connection.type connection show uuid "$CONNECTION_UUID")" in
    802-11-wireless|802-3-ethernet) ;;
    *) exit 0 ;;
esac
[ "$(nmcli -g ipv6.ignore-auto-dns connection show uuid "$CONNECTION_UUID")" = yes ] && exit 0
nmcli connection modify uuid "$CONNECTION_UUID" ipv6.ignore-auto-dns yes
nmcli device reapply "$1"'

FLUSH_RULE=/etc/polkit-1/rules.d/50-resolved-flush-caches.rules
FLUSH_RULE_CONTENT='// Installed by dots (packages/work/install/citrix-secure-access) — see there.
// Lets the Citrix client (runs as the user, outside the login session) flush
// the systemd-resolved cache on connect.
polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.resolve1.flush-caches" && subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});'

# Hook for future profiles + switch the existing ones now (active ones reapplied),
# plus the polkit rule for the client's cache flush
ensure_ipv4_dns() {
    # rules.d is root-only readable → compare via sudo, content on stdin
    if ! printf '%s\n' "$FLUSH_RULE_CONTENT" | sudo cmp -s - "$FLUSH_RULE"; then
        printf '%s\n' "$FLUSH_RULE_CONTENT" | sudo install -m 644 -o root -g root /dev/stdin "$FLUSH_RULE"
        echo "installed $FLUSH_RULE"
    fi
    if ! printf '%s\n' "$DNS_HOOK_CONTENT" | cmp -s - "$DNS_HOOK"; then
        printf '%s\n' "$DNS_HOOK_CONTENT" | sudo install -m 755 -o root -g root /dev/stdin "$DNS_HOOK"
        echo "installed $DNS_HOOK"
    fi
    local uuid type dev
    while IFS=: read -r uuid type; do
        case "$type" in 802-11-wireless|802-3-ethernet) ;; *) continue ;; esac
        [ "$(nmcli -g ipv6.ignore-auto-dns connection show uuid "$uuid")" = yes ] && continue
        sudo nmcli connection modify uuid "$uuid" ipv6.ignore-auto-dns yes
        echo "ipv4-only DNS: $(nmcli -g connection.id connection show uuid "$uuid")"
        dev="$(nmcli -g GENERAL.DEVICES connection show uuid "$uuid" 2>/dev/null || true)"
        [ -z "$dev" ] || sudo nmcli device reapply "$dev"
    done < <(nmcli -t -f UUID,TYPE connection show)
}

installed_ver="$(pacman -Q "$PKGNAME" 2>/dev/null | awk '{print $2}' || true)"

if [ ! -f "$DEB" ]; then
    if [ -n "$installed_ver" ]; then
        echo "citrix-secure-access already installed: $installed_ver"
        ensure_ipv4_dns
    else
        echo "citrix-secure-access: $DEB not found, skipping (nothing installed)."
        echo "  Download 'Citrix Secure Access client for Ubuntu 22/24' (Citrix login required):"
        echo "    $DOWNLOAD_URL"
        echo "  save it to $DEB and run 'dots install work' again."
    fi
    exit 0
fi

# --- read the .deb -------------------------------------------------------------
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
( cd "$WORK" && bsdtar -xf "$DEB" && mkdir control && bsdtar -xf control.tar.* -C control )
[ -f "$WORK/control/control" ] || { echo "no Debian control file in $DEB" >&2; exit 1; }
deb_ver="$(sed -n 's/^Version: *//p' "$WORK/control/control" | sed 's/^[0-9]*://; s/[^A-Za-z0-9._+]/_/g')"

if [ "$installed_ver" = "$deb_ver-$PKGREL" ]; then
    echo "citrix-secure-access already installed: $installed_ver"
    systemctl is-enabled -q nsgverctl.service || sudo systemctl enable --now nsgverctl.service
    ensure_ipv4_dns
    exit 0
fi

sha="$(sha256sum "$DEB" | awk '{print $1}')"
if [ "${KNOWN_SHA256[$deb_ver]:-}" = "$sha" ]; then
    echo "checksum ok for $deb_ver"
elif [ -n "${KNOWN_SHA256[$deb_ver]:-}" ]; then
    echo "checksum MISMATCH for $deb_ver: $sha" >&2
    echo "expected ${KNOWN_SHA256[$deb_ver]} — re-download the .deb" >&2
    exit 1
else
    echo "WARNING: no known checksum for $deb_ver; compare with the Citrix download page:"
    echo "  $sha"
    echo "  (then add it to KNOWN_SHA256 in this script)"
fi

# --- dependencies ----------------------------------------------------------------
command -v yay >/dev/null 2>&1 || { echo "yay not found (needed for gpgme-1)" >&2; exit 1; }
yay -S --needed --noconfirm --asdeps gpgme-1
sudo pacman -D --asdeps gpgme-1 >/dev/null   # in case it was installed explicitly before

# --- build -----------------------------------------------------------------------
rm -rf "$BUILD_DIR" && mkdir -p "$BUILD_DIR"
cp "$DEB" "$BUILD_DIR/"
debname="$(basename "$DEB")"

cat >"$BUILD_DIR/$PKGNAME.install" <<'EOF'
post_install() {
  # Raw sockets for the tunnel (from the Debian postinst)
  setcap cap_net_raw=eip /opt/Citrix/NSGClient/bin/NSGClient
  systemctl reload NetworkManager.service 2>/dev/null || true
  systemctl daemon-reload 2>/dev/null || true
  update-desktop-database -q 2>/dev/null || true
}
post_upgrade() { post_install; }
pre_remove() { pkill -9 -x NSGClient 2>/dev/null || true; }
post_remove() {
  systemctl daemon-reload 2>/dev/null || true
  update-desktop-database -q 2>/dev/null || true
}
EOF

cat >"$BUILD_DIR/PKGBUILD" <<EOF
pkgname=$PKGNAME
pkgver=$deb_ver
pkgrel=$PKGREL
pkgdesc='Citrix Secure Access client (repackaged from $debname)'
arch=(x86_64)
url='https://www.citrix.com/downloads/citrix-secure-access/'
license=(custom)
depends=(gpgme-1 webkit2gtk-4.1 libayatana-appindicator libnotify curl libproxy
         networkmanager glib2 libnl libxml2-legacy pugixml libarchive)
backup=(opt/Citrix/NSGClient/globalConfiguration.json
        opt/Citrix/NSGClient/globalConfiguration.conf
        opt/Citrix/NSGClient/userConfiguration.conf)
options=(!strip !debug)
install=$PKGNAME.install
source=('$debname')
sha256sums=('$sha')
EOF

cat >>"$BUILD_DIR/PKGBUILD" <<'EOF'

package() {
  bsdtar -xf "$srcdir"/data.tar.* -C "$pkgdir"
  cd "$pkgdir"

  # Arch uses merged /usr: /lib, /bin, /sbin, /usr/sbin are symlinks
  _merge() {
    [[ -d $1 && ! -L $1 ]] || return 0
    mkdir -p "$2"
    cp -a "$1"/. "$2"/
    rm -rf "$1"
  }
  _merge lib usr/lib
  _merge lib64 usr/lib
  _merge bin usr/bin
  _merge sbin usr/bin
  _merge usr/sbin usr/bin
  _merge usr/lib64 usr/lib

  # Ubuntu-only bits (upstart/sysv init)
  rm -rf etc/init.d etc/init

  # Steps from the Debian postinst
  local nsg=opt/Citrix/NSGClient
  rm -f "$nsg/save_globalConf_pref.py"   # only migrates old Debian config
  chmod -R 755 "$nsg"
  chmod 644 "$nsg"/globalConfiguration.{conf,json} "$nsg/bin/nsgclient.desktop"
  chmod 444 "$nsg"/{citrix_va.conf,rt_csa.conf,pubkey.asc}
  # No .socketpath here: nsgverctl creates it as a unix socket at runtime;
  # a packaged file would replace the live socket on every upgrade.

  install -Dm644 "$nsg/citrix_va.conf" etc/NetworkManager/conf.d/citrix_va.conf
  install -Dm644 "$nsg/rt_csa.conf" etc/iproute2/rt_tables.d/rt_csa.conf
  install -Dm644 "$nsg/bin/nsgclient.desktop" usr/share/applications/nsgclient.desktop
  install -d usr/bin
  ln -s /$nsg/bin/NSGClient usr/bin/NSGClient
}
EOF

echo "building $PKGNAME $deb_ver"
# -d: repo deps aren't needed to repackage; pacman -U pulls them in below
( cd "$BUILD_DIR" && makepkg -f -d --noconfirm &>"$BUILD_DIR/makepkg.log" ) \
    || { echo "makepkg failed, log: $BUILD_DIR/makepkg.log" >&2; exit 1; }

# --- install ---------------------------------------------------------------------
# NSGClient ignores SIGTERM; a stale client would keep talking to the old socket
pkill -x NSGClient 2>/dev/null && sleep 2
pkill -9 -x NSGClient 2>/dev/null || true
sudo pacman -U --needed --noconfirm "$BUILD_DIR/$PKGNAME"-*.pkg.tar.*
# restart, not just --now: a running nsgverctl keeps the socket of the old install
sudo systemctl enable nsgverctl.service
sudo systemctl restart nsgverctl.service

missing="$(ldd /opt/Citrix/NSGClient/bin/NSGClient /opt/Citrix/NSGClient/service/nsgverctl 2>/dev/null | grep 'not found' || true)"
[ -z "$missing" ] || { echo "WARNING: missing libraries:"; echo "$missing"; }

ensure_ipv4_dns

echo "citrix-secure-access installed: $(pacman -Q "$PKGNAME" | awk '{print $2}')"
