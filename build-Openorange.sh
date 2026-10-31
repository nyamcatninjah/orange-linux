#!/usr/bin/env bash
#
# Openorange 0.4 "suse" — build recipe
# Linux, more fruity
#
# This script writes a KIWI image description and builds an ISO image.
# Run on an openSUSE / SLE host with root privileges.
#
#   chmod +x build-Openorange.sh
#   sudo ./build-Openorange.sh
#
# Output: Openorange-0.4-x86_64.iso

set -euo pipefail

NAME="Openorange"
VERSION="0.4"
CODENAME="suse"
ARCH="x86_64"
OUT="Openorange-0.4-x86_64.iso"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

echo "==> Preparing image description for $NAME $VERSION ($ARCH)"
mkdir -p "$WORKDIR/root/etc"

cat > "$WORKDIR/config.xml" <<'XML'
<image schemaversion="7.4" name="Openorange">
  <description type="system">
    <author>Distro Studio</author>
    <contact>builder@orange</contact>
    <specification>Openorange 0.4 "suse" — Linux, more fruity</specification>
  </description>
  <preferences>
    <version>0.4</version>
    <packagemanager>zypper</packagemanager>
    <locale>en_GB.UTF-8</locale>
    <keytable>gb</keytable>
    <timezone>Europe/London</timezone>
    <type image="iso" firmware="uefi" kernelcmdline="quiet splash vt.global_cursor_default=0" bootloader="grub2"/>
  </preferences>
  <repository path="obs://oss" type="rpm-md" priority="99"/>
  <repository path="obs://packman" type="rpm-md" priority="99"/>
  <packages type="image">
    <package name="base"/>
    <package name="chromium"/>
    <package name="flatpak"/>
    <package name="lxqt"/>
    <package name="sddm"/>
    <package name="vlc"/>
  </packages>
</image>
XML

cat > "$WORKDIR/root/etc/hostname" <<'EOF'
orange
EOF

cat > "$WORKDIR/root/etc/installer.conf" <<'EOF'
INSTALLER=gui
DESKTOP=LXQt
SPLASH=Custom ASCII Art
FILESYSTEM=btrfs
PARTITIONING=snapshots
NETWORK=dhcp
AUTOLOGIN=no
ENCRYPTED_HOME=no
SERVICES=NetworkManager firewalld chronyd
KERNEL_CMDLINE="quiet splash vt.global_cursor_default=0"
EOF

cat > "$WORKDIR/root/etc/bootsplash.ascii" <<'EOF'
   ____                       __ _      ____
  / __ \________  ____  ____  / /(_)____/ / /
 / / / / ___/ _ \/ __ \/ __ \/ // / ___/ / /
/ /_/ / /  /  __/ / / / /_/ / // / /__/ / /
\____/_/   \___/_/ /_/\____/_//_/\___/_/_/
EOF

echo "==> Selected packages (5):"
printf '  %s\n' "chromium" "flatpak" "lxqt" "sddm" "vlc"

need_pkg() {
  command -v "$1" >/dev/null 2>&1
}

if [ "$(id -u)" -ne 0 ]; then
  echo "This script must run as root to build an ISO."
  echo "Re-run with: sudo ./build-Openorange.sh"
  exit 1
fi

echo "==> Checking build dependencies…"
MISSING=()
need_pkg kiwi-ng || MISSING+=(kiwi)
need_pkg xorriso || MISSING+=(xorriso)
need_pkg mksquashfs || MISSING+=(squashfs)
if [ "${#MISSING[@]}" -gt 0 ]; then
  echo "  Installing: ${MISSING[*]}"
  zypper --non-interactive --gpg-auto-import-keys install -y "${MISSING[@]}"
fi

TARGET="$WORKDIR/out"
echo "==> Building ISO with kiwi-ng…"
kiwi-ng system build \
  --description "$WORKDIR" \
  --target-dir "$TARGET" \
  --set-type-iso \
  --set-repo "obs://opensuse.org/tumbleweed" \
  --iso-tool xorriso

BUILT_ISO="$(find "$TARGET" -name '*.iso' -type f | head -n1)"
if [ -z "$BUILT_ISO" ]; then
  echo "ERROR: kiwi-ng did not produce an ISO. Check the log above." >&2
  exit 1
fi

echo "==> Copying built image to $OUT"
cp "$BUILT_ISO" "$OUT"
sha256sum "$OUT" > "$OUT.sha256"

echo
echo "========================================================"
echo "  $NAME $VERSION ($CODENAME) built successfully."
echo "  Output:        $OUT"
echo "  Checksum:      $OUT.sha256"
echo "  Architecture:  $ARCH"
echo "  Base:          openSUSE Tumbleweed"
echo "  Desktop:       LXQt"
echo "  Installer:     Not included in this build script"
echo "  Splash:        ASCII art file staged in the image root"
echo "========================================================"
echo
echo "Boot the ISO in a virtual machine to test it."
