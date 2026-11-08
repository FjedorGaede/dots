#!/usr/bin/env bash
# Write an image to a USB stick. Runs as root (FlasherService: pkexec), so it
# re-checks the target itself instead of trusting the UI:
#   - whole disk (type=disk), transport usb, removable or hotplug
#   - none of its partitions mounted on / /boot /home /efi or as swap
# Then: unmount its partitions, dd with progress on stderr, sync.
#
#   flash.sh <image> <device>     e.g. flash.sh ~/Downloads/arch.iso /dev/sda
#
# stderr = dd's "status=progress" lines (\r-separated) + "error: ..." lines;
# exit 0 = written and synced.
set -euo pipefail

img=${1:-}
dev=${2:-}

die() { echo "error: $*" >&2; exit 1; }

[ -f "$img" ] || die "image not found: $img"
[ -b "$dev" ] || die "not a block device: $dev"

read -r type tran rm hotplug < <(lsblk -dn -o TYPE,TRAN,RM,HOTPLUG "$dev")
[ "$type" = disk ] || die "$dev is not a whole disk"
[ "$tran" = usb ] || die "$dev is not a USB device"
[ "$rm" = 1 ] || [ "$hotplug" = 1 ] || die "$dev is not removable"

img_size=$(stat -Lc %s "$img")
dev_size=$(lsblk -bdn -o SIZE "$dev")
[ "$img_size" -le "$dev_size" ] || die "image is larger than the stick"

while read -r part mnt; do
    case "$mnt" in
        /|/boot|/boot/*|/efi|/home|"[SWAP]") die "$part is mounted on $mnt — refusing" ;;
    esac
done < <(lsblk -lnp -o NAME,MOUNTPOINT "$dev" | awk 'NF == 2')

# Unmount whatever the desktop auto-mounted
lsblk -lnp -o NAME,MOUNTPOINT "$dev" | awk 'NF == 2 { print $1 }' | while read -r part; do
    umount "$part" || die "could not unmount $part"
done

dd if="$img" of="$dev" bs=4M oflag=direct conv=fsync status=progress
sync
