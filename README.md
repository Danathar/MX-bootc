# MX-bootc

## HIGHLY EXPERIMENTAL - NOT AN OFFICIAL MX LINUX BUILD

This repository is **HIGHLY experimental** and **NOT** affiliated with or endorsed by the MX Linux project.

It may break. It is probably broken in multiple ways right now. Use it only for testing.

The goal of this repository is to test whether GPT-5.3-codex can produce a bootc-based MX Linux KDE image that can actually boot.

## What this project currently does

- Builds from Debian `trixie` and bootstraps `bootc`/`ostree` during image build.
- Adds MX repository access and installs MX KDE-oriented packages.
- Produces a bootable container image intended for bootc-based installs/testing.

This is not a byte-for-byte recreation of the official MX Linux KDE ISO build process.

## Build the container image

Local example:

```bash
just build localhost/mx-bootc latest
```

GitHub Actions publish target:

```text
ghcr.io/<your-github-user>/mx-bootc:latest
```

## Build disk images from the container image

Build a QCOW2 disk image:

```bash
just build-qcow2 localhost/mx-bootc latest
```

Build an installer ISO:

```bash
just build-iso localhost/mx-bootc latest
```

Default outputs:

- `output/qcow2/disk.qcow2`
- `output/bootiso/install.iso`

## Configure users/passwords in TOML (installer time)

User creation and passwords should be configured in installer TOML/kickstart, not hardcoded into the container image:

- `disk_config/iso.toml`

Current example in those files:

```text
rootpw --plaintext changeme
user --name=mx --groups=wheel --password=changeme --plaintext --gecos="MX User"
```

These settings are applied during install and are the right place for initial credentials.
They are not part of the immutable image build and therefore are not expected to be reset by a normal `bootc upgrade`.

## Important files

- `Containerfile`: image build order.
- `build_files/build.sh`: package and repository setup.
- `disk_config/iso.toml`: installer kickstart/user config.
- `.github/workflows/build.yml`: build, push, and signing pipeline.
