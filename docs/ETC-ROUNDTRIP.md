# `/etc` and `/usr/etc` round-trip

The image currently has two build-time transitions because bootc's Debian bootstrap and the final committed image have different requirements:

1. `build_files/finalize` copies an existing `/usr/etc` into `/etc` and removes `/usr/etc`. This leaves the tree in the layout expected by the remaining image build and avoids committing both locations.
2. The final `Containerfile` copies the resulting `/etc` back to `/usr/etc`, excluding only runtime-owned `hostname` and `resolv.conf`, then whiteouts `/etc` in the committed layer.

`hostname` and `resolv.conf` are excluded because they are created or mounted for the running machine. `hosts` is different: this repository supplies `system_files/etc/hosts`, and the running image needs an image-owned `/etc/hosts`. It must therefore be copied into `/usr/etc`; excluding it caused the later `/etc` whiteout to remove the repository-provided file from the deployment.

The headless boot test checks that `/etc/hosts`, `/etc/machine-id`, and `/etc/resolv.conf` exist after boot. A future cleanup can remove one of the two transitions, but it should preserve this distinction and keep the smoke assertion as its regression test.

