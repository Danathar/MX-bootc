# Agent guide

## Scope

This repository builds a Debian trixie bootc image with MX KDE styling. It is not MX Linux and does not support mutable-root MX tooling. Read `docs/DESIGN.md` and `docs/MX-COMPAT.md` before changing package selection or desktop utilities.

## Common commands

```bash
just check       # validate Just syntax
just lint        # shellcheck all tracked shell files, including extensionless scripts
just format      # format tracked shell files with shfmt
just build       # build the container image with podman
just build-qcow2 # build a bootable qcow2 with bootc-image-builder
```

The image build needs network access, Podman, and enough storage for Debian/MX packages and the bootc toolchain. Do not treat a documentation-only check as a substitute for an image build when `build_files/` or `Containerfile` changes.

## Change discipline

- Keep each improvement-plan item in one small, independently revertible PR.
- Do not opportunistically change the `/etc` and `/usr/etc` deployment model; that is its own task.
- Prefer CI-testable assertions over manual VM-only checks.
- Preserve the daily build. If a task premise is false, document the finding and stop that task rather than substituting a different change.
- Record every MX tool decision in `docs/MX-COMPAT.md`.

## Template-synced files

`.github/workflows/template-sync.yml` can sync from the upstream image template. Repo-specific files are protected by `.templatesyncignore`; changes to those files should be reviewed against upstream template changes rather than overwritten blindly.

