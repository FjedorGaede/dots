#!/usr/bin/env bash
# install: claude-desktop (category: dev)
# Runs on 'dots install dev' after the category's packages are installed.
# MUST be idempotent — safe to run again on every install.
#
# Installs Claude Desktop with Cowork. The claude-desktop package is
# Anthropic's official build, repackaged in the cachyos repo (Anthropic itself
# only ships a Debian .deb); it pulls in qemu-system-x86, edk2-ovmf and
# virtiofsd. Installed here rather than via packages.txt so the app and its
# Cowork setup are one item. Cowork runs its tasks in a local QEMU/KVM VM,
# which additionally needs:
#   - hardware virtualization enabled in the firmware (/dev/kvm)
#   - the user in the kvm group — /dev/vhost-vsock is only opened by members,
#     even where the desktop grants /dev/kvm without it
#   - the vhost_vsock kernel module
# The app checks this once at launch: restart it after changes, log out and
# back in after joining the group. Sign-in is stored in a Secret Service
# keyring (gnome-keyring) — without one it isn't saved between launches.
set -euo pipefail

if pacman -Q claude-desktop >/dev/null 2>&1; then
    echo "claude-desktop already installed"
else
    sudo pacman -S --needed --noconfirm claude-desktop
fi

if [ ! -e /dev/kvm ]; then
    echo "WARNING: /dev/kvm missing — enable hardware virtualization (VT-x/AMD-V) in the firmware, Cowork needs it"
fi

# getent, not id: id shows the groups of the current session, which lag
# behind until the next login
if getent group kvm | cut -d: -f4 | tr ',' '\n' | grep -qx "$USER"; then
    echo "$USER already in group kvm"
else
    sudo usermod -aG kvm "$USER"
    echo "added $USER to group kvm — log out and back in before starting Cowork"
fi

# Load vhost_vsock on every boot. /dev/vhost-vsock is a static node that
# exists even when the module isn't loaded, so check /sys/module instead.
# Without it the VM fails with "vsock ... address family not supported".
VSOCK_CONF=/etc/modules-load.d/vhost_vsock.conf
if [ "$(cat "$VSOCK_CONF" 2>/dev/null)" != vhost_vsock ]; then
    echo vhost_vsock | sudo tee "$VSOCK_CONF" >/dev/null
    echo "vhost_vsock enabled on boot: $VSOCK_CONF"
fi
if [ ! -d /sys/module/vhost_vsock ]; then
    # fails when the running kernel's modules were removed by a kernel update
    # (no /lib/modules/$(uname -r)) — then only a reboot helps
    if sudo modprobe vhost_vsock; then
        echo "vhost_vsock loaded"
    else
        echo "WARNING: couldn't load vhost_vsock — reboot (kernel updated since boot?)"
    fi
fi

echo "claude-desktop ready for Cowork: $(pacman -Q claude-desktop | awk '{print $2}')"
