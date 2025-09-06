ARG BASE_IMAGE=ghcr.io/rall/bluefin-dx-nvidia-open-howdy:gts
FROM ${BASE_IMAGE}

ARG HOWDY_OUTCOME=success

COPY files/mock-howdy.sh /usr/local/bin/howdy
RUN chmod 0755 /usr/local/bin/howdy

# set mock mode - needs to be parameterized
RUN printf "%s\n" "${HOWDY_OUTCOME}" > /etc/howdy/mock_mode