ARG BASE_IMAGE=ghcr.io/rall/bluefin-dx-nvidia-open-howdy:gts
FROM ${BASE_IMAGE}

RUN rpm-ostree install pamtester strace expect && rpm-ostree cleanup -m

ARG LOGIN_USER=testuser
ARG LOGIN_UID=1000
ARG LOGIN_GID=1000

RUN groupadd -g ${LOGIN_GID} ${LOGIN_USER} \
 && useradd -m -u ${LOGIN_UID} -g ${LOGIN_GID} -s /bin/bash ${LOGIN_USER} \
 && echo "${LOGIN_USER}:${LOGIN_USER}" | chpasswd \
 && usermod -aG video,wheel ${LOGIN_USER}

USER ${LOGIN_USER}
