# Design

## What this project is

MX-bootc is a Debian trixie bootc image with an MX/KDE visual style, selected MX packages, and MX-flavoured defaults. It is not MX Linux, not an official MX build, and not a bootc port of MX Linux's mutable-root tooling.

The image is intentionally built around bootc's model:

- `/usr` is replaced by image deployments rather than edited by the user.
- `/etc` is managed as bootc configuration state and must survive image deployment correctly.
- Package installation at runtime is not a supported update mechanism. Flatpak is the desktop application path; distrobox/podman is the development and CLI path.
- The bootloader and disk-image behavior are owned by bootc-image-builder and the selected systemd-boot integration, not by MX's installer or snapshot tools.

## Explicit constraints

MX packages and defaults were designed for a mutable Debian root, apt-driven upgrades, and MX's live/installer stack. Some are useful as data or desktop configuration; others are incompatible with an immutable deployment. The decisions are recorded in [MX-COMPAT.md](MX-COMPAT.md), and new packages should be evaluated there before being added.

Debian does not currently provide the bootc/ostree combination this image needs, so the build temporarily compiles ostree and bootc. The bootc source is currently the `frostyard/bootc` fork because that is the source the project has historically used and the build depends on its Debian compatibility work. This is a temporary risk, not a guarantee of long-term support. The exit criterion is a Debian-compatible upstream bootc release (or packaged Debian build) that passes this repository's container lint and boot smoke test; at that point the fork should be removed and the source pinned to the upstream release.

The image uses Debian SELinux policy to satisfy bootc-image-builder's labeling stage, but this project does not currently provide a complete targeted SELinux policy or claim an enforcing SELinux security posture. The resulting runtime position is effectively unconfined and must be treated as such until a tested policy exists.

The project selects systemd-boot and removes Debian's signed GRUB package. This keeps the boot path internally consistent with the current image, but means Secure Boot is not provided by the signed-GRUB chain. Secure Boot support requires a separately tested systemd-boot signing/enrollment path or a deliberate return to GRUB.

## Quality bar

The daily build is the current regression signal. Changes to image construction should also pass `just check` and `just lint`; changes that affect boot behavior should pass the headless QEMU smoke test when the required runner support is available. Each plan item should be landed as one small, independently revertible change.

