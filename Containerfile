ARG BASE_IMAGE=ghcr.io/ublue-os/bluefin-dx-nvidia-open:gts
FROM ${BASE_IMAGE} AS base

# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

FROM base
ARG BASE_IMAGE
LABEL org.rall.base_image="${BASE_IMAGE}"
RUN dnf5 -y clean all && dnf5 -y makecache --refresh || true

RUN rpm-ostree install policycoreutils selinux-policy-targeted checkpolicy \
    policycoreutils-python-utils selinux-policy-devel \
    libsepol libsemanage python3-libsemanage v4l-utils && \
    rpm-ostree cleanup -m

COPY selinux/howdy-selinux-setup /usr/libexec/howdy-selinux-setup
RUN chmod 0755 /usr/libexec/howdy-selinux-setup
COPY selinux/howdy_dm.te /usr/share/selinux/howdy/howdy_dm.te
COPY systemd/howdy-selinux-install.service /usr/lib/systemd/system/howdy-selinux-install.service
RUN ln -s ../howdy-selinux-install.service \
    /usr/lib/systemd/system/multi-user.target.wants/howdy-selinux-install.service

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

# add just tasks to global recipes
RUN install -d -m 0755 /usr/share/ublue-os/just
COPY Justfile /usr/share/ublue-os/just/60-blue-howdy.just
RUN chmod 0644 /usr/share/ublue-os/just/60-blue-howdy.just
# Append import to 60-custom.just (both bluefin and bazzite import this file)
RUN printf 'import "/usr/share/ublue-os/just/60-blue-howdy.just"\n' >> /usr/share/ublue-os/just/60-custom.just

RUN ostree container commit

# Verify final image and contents are correct.
RUN bootc container lint
