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
# Uninstall: sudo systemctl disable --now nsgverctl
#            sudo pacman -Rns citrix-secure-access   (also removes gpgme-1)
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

installed_ver="$(pacman -Q "$PKGNAME" 2>/dev/null | awk '{print $2}' || true)"

if [ ! -f "$DEB" ]; then
    if [ -n "$installed_ver" ]; then
        echo "citrix-secure-access already installed: $installed_ver"
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

echo "citrix-secure-access installed: $(pacman -Q "$PKGNAME" | awk '{print $2}')"
