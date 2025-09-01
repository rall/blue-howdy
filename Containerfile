# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

# Base Image
FROM ghcr.io/ublue-os/bluefin-dx-nvidia-open:gts

# Ensure tools & policy are present in the final deployment
RUN rpm-ostree install \
      policycoreutils \
      selinux-policy-targeted \
  && rpm-ostree cleanup -m

# Work around PATH-in-bwrap issues during finalize
RUN ln -sf /usr/sbin/semodule /usr/bin/semodule

COPY selinux/howdy_gdm.cil /usr/share/selinux/howdy/howdy_gdm.cil

# one-shot unit to install the module on the host
# Install a systemd oneshot unit that loads the policy on boot
RUN install -d /usr/lib/systemd/system
RUN <<'EOF' > /usr/lib/systemd/system/howdy-selinux-install.service 
[Unit]
Description=Install Howdy SELinux policy
After=local-fs.target selinux-autorelabel-mark.service
ConditionSecurity=selinux
ConditionPathExists=/usr/share/selinux/howdy/howdy_gdm.cil

[Service]
Type=oneshot
ExecStart=/usr/sbin/semodule -i /usr/share/selinux/howdy/howdy_gdm.cil
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
RUN install -Dm0644 /dev/null /usr/lib/sysusers.d/howdy-gdm.conf && \
    printf 'm gdm video\n' > /usr/lib/sysusers.d/howdy-gdm.conf
RUN install -d /usr/lib/systemd/system-preset && \
    printf 'enable howdy-selinux-install.service\n' > /usr/lib/systemd/system-preset/90-howdy.preset
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh
RUN ostree container commit

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
