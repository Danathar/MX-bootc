#!/bin/bash

set -ouex pipefail

MX_SUITE="trixie"
MX_REPO_BASE="https://mxrepo.com/mx/repo"
MX_KEYRING="/usr/share/keyrings/mx-archive-keyring.gpg"
MX_REPO_SIGNING_FPRS=(
  "8AFEB908376620CCDBFBBB730D0D91C3655D0AF4"
  "0FC0E9FB5B3806B71651351259C16711EFA6FD38"
)

apt_install_with_retry() {
  local attempts=3
  local retry_delay=5
  local i
  for (( i=1; i<=attempts; i++ )); do
    if apt-get install -y --fix-missing "$@"; then
      return 0
    fi
    if [ "${i}" -lt "${attempts}" ]; then
      echo "apt install failed for package(s): $* (attempt ${i}/${attempts} failed); retrying after refreshing package indexes..." >&2
      sleep "${retry_delay}"
      apt-get update -y
    fi
  done
  echo "All ${attempts} attempts failed for package(s): $*" >&2
  return 1
}

# Make sure Debian sources include components commonly used by MX packages.
# Keep third-party source files untouched.
find /etc/apt -type f -name "*.sources" -print0 | while IFS= read -r -d '' file; do
  if grep -Eq '^URIs:\s+https?://.*debian\.org' "$file"; then
    sed -ri 's/^Components: .*/Components: main contrib non-free non-free-firmware/' "$file"
  fi
done
find /etc/apt -type f -name "*.list" -print0 | while IFS= read -r -d '' file; do
  if grep -Eq 'https?://.*debian\.org' "$file"; then
    sed -ri 's#^(deb(-src)?\s+\S+\s+\S+\s+).*$#\1main contrib non-free non-free-firmware#' "$file"
  fi
done

apt-get update -y
apt-get install -y --no-install-recommends ca-certificates curl gnupg gzip

# Core runtime packages needed for bootc images and initramfs generation.
apt-get install -y \
  btrfs-progs \
  cryptsetup \
  dracut \
  e2fsprogs \
  fdisk \
  iproute2 \
  iputils-ping \
  network-manager \
  openssh-server \
  parted \
  podman \
  rsync \
  skopeo \
  sudo \
  xfsprogs \
  zstd

# Hardware support for common Intel, AMD, Realtek, and Atheros systems.
# Keep the split packages explicit so the image manifest shows why firmware is
# present instead of relying on a distribution umbrella package.
apt_install_with_retry \
  firmware-atheros \
  firmware-amd-graphics \
  firmware-iwlwifi \
  firmware-misc-nonfree \
  firmware-realtek \
  intel-microcode \
  amd64-microcode

# Desktop software paths for an immutable system: Flatpak for applications and
# distrobox/podman for development and CLI packages.
apt_install_with_retry \
  distrobox \
  flatpak \
  libnotify-bin \
  plasma-discover \
  plasma-discover-backend-flatpak

# Avoid presenting a PackageKit apt backend that cannot mutate this image.
apt-get purge -y plasma-discover-backend-packagekit || true
flatpak remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# Desktop completeness: sound, printing/scanning, Bluetooth, graphics, power,
# firmware updates, locales, fonts, and a boot splash.
apt_install_with_retry \
  bluez \
  bluez-firmware \
  bluedevil \
  cups \
  fonts-dejavu \
  fwupd \
  intel-media-va-driver-non-free \
  libva2 \
  locales \
  mesa-vulkan-drivers \
  pipewire \
  pipewire-pulse \
  plymouth \
  plymouth-themes \
  power-profiles-daemon \
  sane-airscan \
  system-config-printer \
  thermald \
  wireplumber

# Generate the locale at build time; immutable images cannot rely on a first
# boot locale-generation step.
sed -ri 's/^# (en_US.UTF-8 UTF-8)/\1/' /etc/locale.gen
locale-gen en_US.UTF-8

# bootc-image-builder runs an SELinux labeling stage during disk image creation.
# Debian usually ships policy under /etc/selinux/default, while osbuild expects
# /etc/selinux/targeted/contexts/files/file_contexts.
apt-get install -y \
  selinux-basics \
  selinux-policy-default

if [ -f /etc/selinux/default/contexts/files/file_contexts ] && \
  [ ! -f /etc/selinux/targeted/contexts/files/file_contexts ]; then
  mkdir -p /etc/selinux/targeted/contexts/files
  ln -sf \
    /etc/selinux/default/contexts/files/file_contexts \
    /etc/selinux/targeted/contexts/files/file_contexts
fi

# Bootstrap MX signing keys from the official mx-gpg-keys package.
mx_keys_rel_path="$({
  curl -fsSL "${MX_REPO_BASE}/dists/${MX_SUITE}/main/binary-amd64/Packages.gz" \
    | gzip -dc \
    | awk '
        BEGIN{RS="";FS="\n"; path=""}
        $1=="Package: mx-gpg-keys" {
          for(i=1;i<=NF;i++) {
            if($i ~ /^Filename: /) { path=substr($i,11) }
          }
        }
        END { print path }
      '
})"

if [ -z "${mx_keys_rel_path}" ]; then
  echo "Failed to discover mx-gpg-keys package path" >&2
  exit 1
fi

curl -fsSL "${MX_REPO_BASE}/${mx_keys_rel_path}" -o /tmp/mx-gpg-keys.deb
dpkg -i /tmp/mx-gpg-keys.deb
rm -f /tmp/mx-gpg-keys.deb

mx_keybox="/usr/share/mx-gpg-keys/mx-gpg-keyring"
GNUPGHOME="$(mktemp -d)"
chmod 700 "${GNUPGHOME}"
gpg --batch --homedir "${GNUPGHOME}" --no-default-keyring --keyring "${mx_keybox}" --export > "${MX_KEYRING}"

# mx-gpg-keys can lag behind active repo signing keys. Import fallback keys if missing.
for fpr in "${MX_REPO_SIGNING_FPRS[@]}"; do
  if ! gpg --batch --homedir "${GNUPGHOME}" --no-default-keyring --keyring "${MX_KEYRING}" \
    --list-keys "${fpr}" >/dev/null 2>&1; then
    curl -fsSL \
      "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x${fpr}" \
      -o /tmp/mx-repo-signing-key.asc
    gpg --batch --homedir "${GNUPGHOME}" --no-default-keyring --keyring "${MX_KEYRING}" \
      --import /tmp/mx-repo-signing-key.asc
    rm -f /tmp/mx-repo-signing-key.asc
  fi
done

rm -rf "${GNUPGHOME}"

cat > /etc/apt/sources.list.d/mx.list <<EOF_MX
# MX Linux repository for trixie-based MX 25 package stream
deb [signed-by=${MX_KEYRING}] ${MX_REPO_BASE}/ ${MX_SUITE} main non-free ahs
EOF_MX

apt-get update -y

# Install the kernel from the MX repository (AHS/Liquorix version)
apt_install_with_retry linux-image-liquorix-amd64

# Prevent a future package addition from silently replacing systemd with a
# SysV init implementation.
if ! dpkg-query -W -f='${Status}' systemd-sysv 2>/dev/null | grep -q 'install ok installed'; then
  echo "systemd-sysv is required but is not installed" >&2
  exit 1
fi

# KDE stack plus MX KDE defaults/tools.
apt_install_with_retry \
  kde-standard \
  kde-plasma-desktop \
  sddm \
  adwaita-icon-theme \
  hicolor-icon-theme \
  papirus-icon-theme \
  papirus-mxblue \
  papirus-folder-colors \
  mx-icons-start \
  mx-comfort-themes \
  mx-greybird-themes \
  breeze-icon-theme \
  libgtk-3-bin \
  desktop-defaults-mx-kde \
  plasma-modified-defaults-mx \
  plasma-look-and-feel-theme-mx \
  sddm-modified-init

# MX tools that mutate an apt-managed root or create live media are not part of
# this image's contract. Hide any menu entries pulled in indirectly by MX
# defaults so users do not launch a known-incompatible tool by accident.
for desktop in /usr/share/applications/*.desktop; do
  [ -f "${desktop}" ] || continue
  if grep -Eq '^Exec=.*(mx-snapshot|mx-installer|minstall|mx-packageinstaller|mx-repo-manager|mx-updater|apt-notifier|mx-boot-options|mx-cleanup)' "${desktop}"; then
    if grep -q '^NoDisplay=' "${desktop}"; then
      sed -i 's/^NoDisplay=.*/NoDisplay=true/' "${desktop}"
    else
      printf '\nNoDisplay=true\n' >> "${desktop}"
    fi
  fi
done

# Keep VM boots clean on non-NVIDIA hardware and with NetworkManager only.
rm -f /etc/modules-load.d/nvidia.conf
rm -f /etc/systemd/system/network-online.target.wants/systemd-networkd-wait-online.service
rm -f /etc/systemd/system/sysinit.target.wants/hwclock-mx.service
systemctl disable nvidia-persistenced.service || true
systemctl mask nvidia-persistenced.service || true
systemctl disable systemd-networkd.service systemd-networkd-wait-online.service || true
systemctl mask systemd-networkd-wait-online.service || true
systemctl disable hwclock-mx.service || true
systemctl mask hwclock-mx.service || true

# Some MX icon/theme combinations do not provide this exact symbolic name.
# Use the broader symbolic icon name that is consistently present.
for f in \
  /usr/share/plasma/plasmoids/org.kde.plasma.kicker/contents/config/main.xml \
  /usr/share/plasma/plasmoids/org.kde.plasma.kicker/contents/ui/ConfigGeneral.qml \
  /usr/share/plasma/plasmoids/org.kde.plasma.kickoff/contents/config/main.xml \
  /usr/share/plasma/plasmoids/org.kde.plasma.kickoff/contents/ui/code/tools.js; do
  [ -f "${f}" ] && sed -i \
    -e 's/start-here-kde-symbolic/start-here-kde/g' \
    -e 's#/usr/share/icons/mxfcelogo-rounded.png#start-here-kde#g' \
    "${f}"
done

# Force icon cache update.
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  find /usr/share/icons -maxdepth 1 -type d | while read -r dir; do
    if [ -f "$dir/index.theme" ]; then
      gtk-update-icon-cache -f -t "$dir" || true
    fi
  done
fi

# Keep compatibility for MX defaults that still reference this absolute path.
if [ ! -f /usr/share/icons/mxfcelogo-rounded.png ] && \
   [ -f /usr/share/icons/HighContrast/32x32/places/start-here.png ]; then
  cp -f /usr/share/icons/HighContrast/32x32/places/start-here.png \
    /usr/share/icons/mxfcelogo-rounded.png
fi

systemctl enable NetworkManager.service
systemctl enable sddm.service
systemctl enable ssh.service
systemctl enable cups.service
systemctl enable bluetooth.service
systemctl enable power-profiles-daemon.service
systemctl enable thermald.service
systemctl enable bootc-fetch-apply-updates.timer
systemctl enable mx-bootc-first-boot.service
systemctl --global enable pipewire.socket pipewire-pulse.socket wireplumber.service

if command -v plymouth-set-default-theme >/dev/null 2>&1; then
  plymouth-set-default-theme spinner || true
fi

mkdir -p /usr/share/mx-bootc-kde
apt list --installed > /usr/share/mx-bootc-kde/desktop-packages.txt

if grep -q '^BUILD_ID=' /usr/lib/os-release; then
  sed -i "s/^BUILD_ID=.*/BUILD_ID=\"${BUILD_ID}\"/" /usr/lib/os-release
else
  echo "BUILD_ID=\"${BUILD_ID}\"" >> /usr/lib/os-release
fi
