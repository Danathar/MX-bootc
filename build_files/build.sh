#!/bin/bash

set -ouex pipefail

MX_SUITE="bookworm"
MX_REPO_BASE="https://mxrepo.com/mx/repo"
MX_KEYRING="/usr/share/keyrings/mx-archive-keyring.gpg"

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
rm -rf "${GNUPGHOME}"

cat > /etc/apt/sources.list.d/mx.list <<EOF_MX
# MX Linux repository for bookworm-based MX 23/25 package streams
deb [signed-by=${MX_KEYRING}] ${MX_REPO_BASE}/ ${MX_SUITE} main non-free ahs
EOF_MX

apt-get update -y

# KDE stack plus MX KDE defaults/tools.
apt-get install -y \
  kde-standard \
  kde-plasma-desktop \
  sddm \
  mx-apps-kde \
  desktop-defaults-mx-kde \
  plasma-modified-defaults-mx \
  plasma-look-and-feel-theme-mx \
  sddm-modified-init

systemctl enable NetworkManager.service
systemctl enable sddm.service

mkdir -p /usr/share/mx-bootc-kde
apt list --installed > /usr/share/mx-bootc-kde/desktop-packages.txt

if grep -q '^BUILD_ID=' /usr/lib/os-release; then
  sed -i "s/^BUILD_ID=.*/BUILD_ID=\"${BUILD_ID}\"/" /usr/lib/os-release
else
  echo "BUILD_ID=\"${BUILD_ID}\"" >> /usr/lib/os-release
fi
