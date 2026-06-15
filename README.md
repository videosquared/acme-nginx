# ACME NGINX

## Environment variables:
`ACME_SERVER`: `[letsencrypt (default) | letsencrypt_test | zerossl | sslcom | google | googletest | actalis]`  
`ACME_AUTO_CERT_ENABLED`: `[true (default) | false]` — when `false`, skips ACME account registration and certificate issuance/renewal entirely. `ACME_EMAIL`, `CF_Token`, `CF_Account_ID`, and `ACME_CERT_n` are not required in this mode. Useful if you're providing your own certificates via a mounted volume.  
`ACME_EMAIL`: Email used for Let's Encrypt account (REQUIRED if `ACME_AUTO_CERT_ENABLED=true`).  
`CF_Token`: Token for Cloudflare API access (REQUIRED if `ACME_AUTO_CERT_ENABLED=true`).  
`CF_Account_ID`: Cloudflare account ID (REQUIRED if `ACME_AUTO_CERT_ENABLED=true`).  
`ACME_RENEWAL_DAY`: Days before triggering renewal (Default: 70)  
`ACME_CERT_1`: CSV format for list of SANs for this certificate (REQUIRED if `ACME_AUTO_CERT_ENABLED=true`).  
`ACME_CERT_n`: CSV format for list of SANs for this certificate (Optional).

## Mount points:
`/opt/acme-sh`: Where the ACME account data (account key, registration, CA cache) is stored.  
`/opt/certs`: Where the issued SSL certificates, keys, and per-domain configs (including DNS API credentials) are stored.  
`/etc/nginx/nginx.conf`: (OPTIONAL) Mount a custom nginx.conf main config file.  
`/etc/nginx/conf.d/http.conf`: (REQUIRED*) This is where you define your HTTP servers, you can use it to import other servers or just create your servers here.  
`/etc/nginx/conf.d/stream.conf`: (REQUIRED*) Even if this is empty, you still need to mount the file.  
`/etc/nginx/conf.d`: Supporting files for the nginx server.  
`/var/run/docker.sock`: (OPTIONAL) Mount the Docker socket to allow renewal hooks to restart/reload other containers (e.g. `docker restart openbao`). **Warning**: this grants the container full control over the Docker host — only mount on trusted single-host setups.

\* If you mount `/etc/nginx/conf.d` you don't need to mount the individual `http.conf` and `stream.conf`.

## Notes
- If `ACME_AUTO_CERT_ENABLED=false`, you must generate your own certificates by exec'ing into the container and running the commands yourself (or supply your own) and ensure `/etc/nginx/conf.d` references valid certificate paths before the container starts — `nginx -t` runs on startup and the container will fail to start if the config is invalid or referenced cert files are missing.
- `/opt/acme-sh` and `/opt/certs` should both be treated as sensitive: `/opt/certs/<domain>/<domain>.conf` contains the saved Cloudflare API credentials for that domain alongside its certificate files.

## Logging
Nginx access and error logs are sent to stdout/stderr (`docker logs`).  
**DO NOT** put log locations in your own custom code.

## Manual certificate management (ACME_AUTO_CERT_ENABLED=false)

When `ACME_AUTO_CERT_ENABLED=false`, the container starts nginx and a 
renewal daemon (cron) only — it does not issue any certificates itself. 
You issue certs manually via `docker compose exec`, which inherits the 
container's environment (CF_Token, CF_Account_ID, etc.) automatically.

### First-time setup

1. Create empty placeholder config files so `nginx -t` passes on first boot:
```bash
   mkdir -p /opt/acme-nginx/nginx/conf
   touch /opt/acme-nginx/nginx/conf/http.conf
   touch /opt/acme-nginx/nginx/conf/stream.conf
```

2. Start the container:
```bash
   docker compose up -d
```

3. Issue a certificate (single domain):
```bash
   docker compose exec acme-nginx acme.sh --issue \
     -d example.com \
     --dns dns_cf \
     --renew-hook "nginx -s reload"
```

   Multi-SAN:
```bash
   docker compose exec acme-nginx acme.sh --issue \
     -d example.com -d www.example.com \
     --dns dns_cf \
     --renew-hook "nginx -s reload"
```

   Certs are written to `/opt/certs/<domain>_ecc/` (persisted volume).
   The account is auto-registered on first `--issue` if none exists.

4. Write your server block(s) in `/opt/acme-nginx/nginx/conf/http.conf`, 
   referencing the issued cert paths, e.g.:
```nginx
   server {
       listen 443 ssl;
       server_name example.com;

       ssl_certificate     /opt/certs/example.com_ecc/fullchain.cer;
       ssl_certificate_key /opt/certs/example.com_ecc/example.com.key;

       location / {
           proxy_pass http://your-upstream;
       }
   }
```

5. Reload nginx to pick up the new config:
```bash
   docker compose exec acme-nginx nginx -s reload
```

### Other useful commands

List all managed certificates:
```bash
docker compose exec acme-nginx acme.sh --list
```

Manually trigger a renewal check (normally handled by the cron daemon):
```bash
docker compose exec acme-nginx acme.sh --cron
```

Revoke and remove a certificate:
```bash
docker compose exec acme-nginx acme.sh --revoke -d example.com
docker compose exec acme-nginx acme.sh --remove -d example.com
```
