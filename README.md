# mx25-kde-bootc

Bootable container image definition for an MX Linux KDE-style system, based on Debian bootc.

## What this image does

- Starts from `docker.io/library/debian:stable` and bootstraps `bootc`/`ostree` during build.
- Adds MX repository access for `bookworm` with keyring validation.
- Installs KDE plus MX KDE defaults/tools (`mx-apps-kde`, `desktop-defaults-mx-kde`, and related theme/default packages).
- Rebuilds initramfs and finalizes the rootfs for bootc deploys.

## Important assumptions

- MX 25.x is still based on Debian `bookworm`, and MX packages are sourced from `https://mxrepo.com/mx/repo`.
- This repository is a starting point for iterative testing, not a verified byte-for-byte rebuild of the official MX KDE ISO.

## Quick start

1. Build the image locally:

```bash
cd image-template
just build localhost/mx25-kde-bootc latest
```

2. Build a VM disk image:

```bash
just build-qcow2 localhost/mx25-kde-bootc latest
```

3. (Optional) Run the VM output:

```bash
just run-vm-qcow2 localhost/mx25-kde-bootc latest
```

## Switching a host to this image

After you publish your image to a registry:

```bash
sudo bootc switch ghcr.io/<username>/mx25-kde-bootc:latest
```

## Config files you probably want to edit

- `Containerfile`: base image and build flow.
- `build_files/build.sh`: MX repo setup + package selection.
- `disk_config/iso.toml`: installer `bootc switch` target.
- `.github/workflows/build.yml`: image metadata and publish behavior.

## Known gaps

- Package set parity with official MX KDE media is approximate.
- No separate AHS/non-AHS variant split yet.
- NVIDIA/specialized hardware paths are not yet tuned.
