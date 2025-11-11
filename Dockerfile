FROM debian:trixie

RUN apt update && apt dist-upgrade -y && apt install curl gnupg2 ca-certificates lsb-release debian-archive-keyring git -y
RUN curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor | tee /etc/apt/keyrings/nginx-archive-keyring.gpg >/dev/null
RUN echo "deb [signed-by=/etc/apt/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/mainline/debian `lsb_release -cs` nginx" | tee /etc/apt/sources.list.d/nginx.list
RUN printf "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" | tee /etc/apt/preferences.d/99nginx
RUN apt update && apt install nginx -y
RUN mkdir /etc/ssl/acme && mkdir /opt/acme
RUN git clone https://github.com/acmesh-official/acme.sh.git /tmp/acme.sh && cd /tmp/acme.sh && ./acme.sh --install --nocron --home /opt/acme --cert-home /etc/ssl/acme && cd ~ && rm -rf /tmp/acme.sh
WORKDIR /opt
COPY entrypoint.sh /opt/entrypoint.sh
COPY nginx.conf /etc/nginx/nginx.conf

VOLUME ["/etc/ssl/acme", "/opt/acme/ca", "/etc/nginx/conf.d"]

EXPOSE 80
EXPOSE 443

ENTRYPOINT [ "/bin/bash", "/opt/entrypoint.sh" ]
