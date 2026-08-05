# MX compatibility matrix

This image borrows MX's package selection, artwork, and desktop defaults. It does not promise that MX's mutable-system tools work on an immutable bootc deployment.

| Component or family | Verdict | Reason |
| --- | --- | --- |
| `desktop-defaults-mx-kde` | keep | Desktop defaults are data and configuration, not a mutable-root workflow. |
| `plasma-modified-defaults-mx` | keep | Plasma defaults can be applied at image build time. |
| `plasma-look-and-feel-theme-mx` | keep | Theme assets are compatible with the immutable image model. |
| `mx-comfort-themes`, `mx-greybird-themes` | keep | Theme assets are safe to ship in `/usr`. |
| `papirus-mxblue`, `mx-icons-start` | keep | Icon assets do not require runtime package mutation. |
| `mx-snapshot` | drop | Snapshot/live-media creation is replaced by the bootc image and disk builder. |
| `mx-installer` / `minstall` | drop | Installation is owned by bootc-image-builder/Anaconda configuration. |
| `mx-packageinstaller` | drop | It assumes apt can mutate the deployed root; use Discover/Flatpak instead. |
| `mx-repo-manager` | drop | Runtime source edits are ephemeral or conflict with image updates. |
| `mx-updater`, `apt-notifier` | replace | Image updates need bootc staging, reboot, and a desktop notification path. |
| `mx-boot-options` | drop | It is GRUB-oriented while this image selects systemd-boot. |
| `mx-cleanup` | drop | Cleanup of a mutable root is not a user operation on a committed image. |
| `mx-tweak` | evaluate | Per-user settings may work, but each action must avoid editing `/usr`. |
| `mx-conky` | evaluate | It is a user-session feature and is independent of image mutation. |
| `mx-fluxbox-*` | drop for KDE image | Fluxbox integration is outside this image's supported desktop contract. |
| MX live/installer menu entries | keep only when valid | Dead entries must be hidden with `NoDisplay=true` rather than left to fail. |

This matrix is a design contract, not a claim that every package is currently installed. When a package is added or removed, update the relevant row and explain the image-model impact in the change description.
