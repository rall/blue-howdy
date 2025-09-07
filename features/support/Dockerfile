ARG BASE_IMAGE=ghcr.io/rall/bluefin-dx-nvidia-open-howdy:gts
FROM ${BASE_IMAGE}

ARG HOWDY_OUTCOME=success

COPY features/support/files/mock-howdy.sh /usr/local/bin/howdy
RUN chmod 0755 /usr/local/bin/howdy

RUN rpm-ostree install pamtester && \
    rpm-ostree cleanup -m

RUN printf "%s\n" "${HOWDY_OUTCOME}" > /etc/howdy/mock_mode

ARG LOGIN_USER=testuser
ARG LOGIN_UID=1000
ARG LOGIN_GID=1000

# create user, set a password equal to the username (tests can change it if needed)
RUN groupadd -g ${LOGIN_GID} ${LOGIN_USER} \
 && useradd -m -u ${LOGIN_UID} -g ${LOGIN_GID} -s /bin/bash ${LOGIN_USER} \
 && echo "${LOGIN_USER}:${LOGIN_USER}" | chpasswd \
 && usermod -aG video,wheel ${LOGIN_USER}
