# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

# Base Image
FROM ghcr.io/ublue-os/bluefin-dx-nvidia-open:gts

# Ensure tools & policy are present in the final deployment
RUN rpm-ostree install \
      policycoreutils \
      selinux-policy-targeted \
      checkpolicy \
      policycoreutils-python-utils \
  && rpm-ostree cleanup -m

# Work around PATH-in-bwrap issues during finalize
RUN ln -sf /usr/sbin/semodule /usr/bin/semodule

RUN install -Dm0644 /dev/null /usr/lib/sysusers.d/howdy-gdm.conf && \
    printf 'm gdm video\n' > /usr/lib/sysusers.d/howdy-gdm.conf

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh
RUN ostree container commit

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
