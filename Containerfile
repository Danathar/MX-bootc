# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

# Bootc base files for Debian
FROM docker.io/library/debian:trixie

COPY system_files /
LABEL containers.bootc="1"

ARG DEBIAN_FRONTEND=noninteractive
ARG BUILD_ID=${BUILD_ID}

# Bootstrap bootc/ostree first, then apply MX KDE customizations.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=cache,dst=/var/lib/apt \
    --mount=type=cache,dst=/var/lib/dpkg/updates \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/install-bootloader && \
    /ctx/install-bootc && \
    /ctx/build.sh && \
    /ctx/build-initramfs && \
    /ctx/finalize

# Verify final image and contents are correct.
RUN bootc container lint
