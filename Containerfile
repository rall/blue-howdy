# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

# Base Image
FROM ghcr.io/ublue-os/bluefin-dx-nvidia-open:gts

RUN dnf5 -y clean all && \
    dnf5 -y makecache --refresh || true

# Ensure tools & policy are present in the final deployment
RUN rpm-ostree install policycoreutils selinux-policy-targeted secilc &&\
    rpm-ostree cleanup -m

# Avoid PATH issues during finalize
RUN ln -sf /usr/sbin/semodule /usr/bin/semodule

# Copy policy and unit, enable via wants-symlink
COPY selinux/howdy_gdm.cil /usr/share/selinux/howdy/howdy_gdm.cil
COPY systemd/howdy-selinux-install.service /usr/lib/systemd/system/howdy-selinux-install.service
RUN ln -s ../howdy-selinux-install.service \
    /usr/lib/systemd/system/multi-user.target.wants/howdy-selinux-install.service

# Ensure Gnome Display Manager in video group
RUN install -Dm0644 /dev/null /usr/lib/sysusers.d/howdy-gdm.conf && \
    printf 'm gdm video\n' > /usr/lib/sysusers.d/howdy-gdm.conf

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

RUN ostree container commit

# Verify final image and contents are correct.
RUN bootc container lint
