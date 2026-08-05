# MX-bootc

## HIGHLY EXPERIMENTAL - NOT AN OFFICIAL MX LINUX BUILD

This repository is **HIGHLY experimental** and **NOT** affiliated with or endorsed by the MX Linux project.

It may break — in fact, it is expected to be broken in multiple ways right now. Use it only for testing.

This repository is an AI-developed experiment and should be treated as such. The goal is to test whether an agent can produce a Debian bootc KDE image with MX styling that can actually boot.

## What this project currently does

- Builds from Debian `trixie` and currently bootstraps `bootc`/`ostree` during image build.
- Adds MX repository access and installs MX KDE-oriented packages.
- Produces a bootable container image intended for bootc-based installs/testing.

For the supported design and the fate of MX tools, see [docs/DESIGN.md](docs/DESIGN.md) and [docs/MX-COMPAT.md](docs/MX-COMPAT.md). This is a Debian trixie bootc image with MX KDE styling and defaults — not MX Linux and not a bootc port of MX's mutable tooling.

MX artwork, themes, and trademarks remain the property of their respective owners. This project is unaffiliated with MX Linux; check the licenses and trademark terms for every asset before redistributing a build.

This is not a byte-for-byte recreation of the official MX Linux KDE ISO build process.

## Build the container image

The expensive bootc/ostree bootstrap is published separately as a pinned base image. For a local build, build that base once and then build the desktop image:

```bash
just build-base
just build localhost/mx-bootc latest
```

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
- `disk_config/disk.toml`

Current example in those files:

```text
rootpw --plaintext changeme
user --name=mx --groups=sudo --password=changeme --plaintext --gecos="MX User"
```

These settings are applied during install and are the right place for initial credentials. `changeme` is an installer-time placeholder: change it immediately on first login. These credentials are not part of the immutable image build and therefore are not expected to be reset by a normal `bootc upgrade`.

## Updating and software

This image updates by staging a new bootc deployment and rebooting into it. Runtime apt mutations are not supported. The intended desktop application path is Flatpak/Discover, and the intended development and CLI path is distrobox with podman.

## Verify a signed image

When a release publishes `cosign.pub`, verify the image digest before use:

```bash
cosign verify --key cosign.pub ghcr.io/<your-github-user>/mx-bootc@sha256:<digest>
```

Do not treat a mutable tag such as `latest` as an integrity guarantee.

## Important files

- `Containerfile`: image build order.
- `Containerfile.base`: pinned bootc/ostree build base.
- `build_files/build.sh`: package and repository setup.
- `disk_config/iso.toml`: installer kickstart/user config.
- `.github/workflows/build.yml`: build, push, and signing pipeline.
- `docs/DESIGN.md`: project boundaries and bootc design decisions.
- `docs/MX-COMPAT.md`: compatibility decisions for MX packages and tools.
