ARG BASE_IMAGE=ghcr.io/rall/bluefin-dx-nvidia-open-howdy:gts
FROM ${BASE_IMAGE}

RUN rpm-ostree install pamtester strace expect && rpm-ostree cleanup -m

# Mark mutable state mount points for CI. Docker will back these with named volumes
# or bind mounts in the workflow, letting us simulate a “reboot” by reusing them.
VOLUME ["/var", "/etc"]

ARG LOGIN_USER=testuser
ARG LOGIN_UID=1000
ARG LOGIN_GID=1000

ENV SELINUX=enforcing

RUN groupadd -g ${LOGIN_GID} ${LOGIN_USER} \
 && useradd -m -u ${LOGIN_UID} -g ${LOGIN_GID} -s /bin/bash ${LOGIN_USER} \
 && echo "${LOGIN_USER}:${LOGIN_USER}" | chpasswd \
 && usermod -aG video,wheel ${LOGIN_USER}

USER ${LOGIN_USER}
