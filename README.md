# ACME NGINX

## Environment variables:
`ACME_SERVER`: `[letsencrypt (default) | letsencrypt_test | zerossl | sslcom | google | googletest | actalis]`  
`ACME_EMAIL`: Email used for lets encrypt account (REQUIRED).  
`CF_Token`: Token for Cloudflare API access (REQUIRED).  
`CF_Account_ID`: Cloudflare account ID (REQUIRED).  
`ACME_RENEWAL_DAY`: Days before triggering renewal (Default: 70)  
`ACME_CERT_1`: CSV format for list of SANs for this certificate (REQUIRED).  
`ACME_CERT_n:`: CSV format for list of SANs for this certificate (Optional).

## Mount points:
`/etc/ssl/acme`: Where the ACME SSL certificates will be stored.  
`/opt/acme/ca`: Where the ACME CA data will be stored.  
`/etc/nginx/nginx.conf`: (OPTIONAL) Mount a custom nginx.conf main config file.  
`/etc/nginx/conf.d/http.conf`: (REQUIRED*) This is where you define your HTTP servers, you can use it to import other servers or just create your servers here.  
`/etc/nginx/conf.d/stream.conf`: (REQUIRED*) Even if this is empty, you still need to mount the file.  
`/etc/nginx/conf.d`: Supporting files for the nginx server.   

\* If you mount the `/etc/nginx/conf.d` you dont need to mount the individual `http.conf` and `stream.conf`.
