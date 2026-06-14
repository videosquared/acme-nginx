FROM debian:trixie-slim

RUN apt update && \
    apt dist-upgrade -y && \
    apt install curl gnupg2 ca-certificates lsb-release debian-archive-keyring git tini -y && \
    rm -rf /var/lib/apt/lists/*

# Install supercronic
ARG SUPERCRONIC=supercronic-linux-amd64
ARG SUPERCRONIC_VERSION=v0.2.46
ARG SUPERCRONIC_SHA1=5bcefed628e32adc08e32634db2d10e9230dbca0

RUN curl -fsSLO "https://github.com/aptible/supercronic/releases/download/${SUPERCRONIC_VERSION}/${SUPERCRONIC}" && \
    echo "${SUPERCRONIC_SHA1}  ${SUPERCRONIC}" | sha1sum -c - && \
    chmod +x "${SUPERCRONIC}" && \
    mv "${SUPERCRONIC}" /usr/local/bin/supercronic

# Install docker-cli using docker repos
RUN install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc && \
    chmod a+r /etc/apt/keyrings/docker.asc && \
    tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

RUN apt update && \
    apt install docker-ce-cli -y && \
    rm -rf /var/lib/apt/lists/*

# Install nginx
RUN curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor | tee /etc/apt/keyrings/nginx-archive-keyring.gpg >/dev/null
RUN echo "deb [signed-by=/etc/apt/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/mainline/debian `lsb_release -cs` nginx" | tee /etc/apt/sources.list.d/nginx.list
RUN printf "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" | tee /etc/apt/preferences.d/99nginx

RUN apt update && \
    apt install nginx -y && \
    rm -rf /var/lib/apt/lists/*

# Install acme-sh
ENV LE_WORKING_DIR=/opt/bin
ENV LE_CONFIG_HOME=/opt/acme-sh
ENV CERT_HOME=/opt/certs

# RUN mkdir /opt/acme-sh && mkdir /opt/bin
RUN git clone https://github.com/acmesh-official/acme.sh.git /tmp/acme.sh && \
    cd /tmp/acme.sh && \
    ./acme.sh --install --nocron && \
    cd ~ && rm -rf /tmp/acme.sh

ENV PATH="/opt/bin:${PATH}"

WORKDIR /opt
COPY entrypoint.sh /opt/entrypoint.sh
COPY nginx.conf /etc/nginx/nginx.conf

VOLUME ["/opt/acme-sh", "/opt/certs", "/etc/nginx/conf.d"]

EXPOSE 80
EXPOSE 443

ENTRYPOINT ["tini", "-g", "--", "/bin/bash", "/opt/entrypoint.sh" ]
