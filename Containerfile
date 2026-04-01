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

# Fix NVIDIA suspend/resume on images that ship NVreg_UseKernelSuspendNotifiers=1.
# The kernel-notifier path handles save/restore internally — a systemd-sleep hook
# writing to /proc/driver/nvidia/suspend conflicts and crashes the driver.
# We only need to:
#   1. Remove the S0ix option (conflicts with S3 deep sleep)
#   2. Deduplicate PreserveVideoMemoryAllocations
#   3. Add an SELinux allow for systemd-sleep to write VRAM dumps to TemporaryFilePath
RUN if echo "${BASE_IMAGE}" | grep -qi nvidia; then \
        sed -i '/NVreg_EnableS0ixPowerManagement/d' /usr/lib/modprobe.d/nvidia.conf && \
        awk '!seen[$0]++' /usr/lib/modprobe.d/nvidia.conf > /tmp/nvidia.conf && \
        mv /tmp/nvidia.conf /usr/lib/modprobe.d/nvidia.conf; \
    fi

COPY selinux/howdy-selinux-setup /usr/libexec/howdy-selinux-setup
COPY build_files/howdy-pam /usr/libexec/howdy-pam
RUN chmod 0755 /usr/libexec/howdy-selinux-setup \
    /usr/libexec/howdy-pam
COPY selinux/howdy_dm.te /usr/share/selinux/howdy/howdy_dm.te
COPY selinux/howdy_dm.fc /usr/share/selinux/howdy/howdy_dm.fc
COPY systemd/howdy-selinux-install.service /usr/lib/systemd/system/howdy-selinux-install.service
COPY systemd/howdy-pam.service /usr/lib/systemd/system/howdy-pam.service
COPY systemd/howdy-pam.path /usr/lib/systemd/system/howdy-pam.path
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

# Work around BIB depsolve bug (osbuild/bootc-image-builder#1188):
# BIB can't read file:// GPG keys from inside the container during ISO builds.
# Disable the repo entirely — BIB doesn't need it for Anaconda installer packages.
# If that changes, the build will fail with a missing dependency rather than pulling unverified packages.
RUN sed -i 's/enabled=1/enabled=0/' /etc/yum.repos.d/terra-mesa.repo 2>/dev/null || true

RUN ostree container commit

# Verify final image and contents are correct.
RUN bootc container lint
