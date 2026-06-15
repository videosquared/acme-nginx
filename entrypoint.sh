#!/usr/bin/env bash
set -euo pipefail

ACME_SERVER="${ACME_SERVER:-letsencrypt}"
CRONTAB_FILE="${LE_CONFIG_HOME}/crontab"
ACME_AUTO_CERT_ENABLED="${ACME_AUTO_CERT_ENABLED:-true}"
ACME_RENEWAL_DAY="${ACME_RENEWAL_DAY:-70}"

main() {
    if [ "${ACME_AUTO_CERT_ENABLED}" = "true" ]; then
        run_automated_certs
    else
        log "ACME_AUTO_CERT_ENABLED is false - skipping generating certs automatically."
    fi

    log "Validating nginx config"
    # Hard failure
    nginx -t

    # Soft failure
    # if ! nginx -t; then
    #     log "WARNING: nginx config validation failed — attempting to start anyway."
    # fi

    log "Starting nginx (foreground)"
    exec nginx -g "daemon off;"
}

run_automated_certs() {
    check_env_vars_exist

    log "Trying to register account."
    acme.sh --register-account --server ${ACME_SERVER} -m ${ACME_EMAIL}

    local i=1
    while true; do
        local var_name="ACME_CERT_${i}"
        local value="${!var_name:-}"

        log "Checking ${var_name}."

        if [ -z "${value}" ]; then
            log "ACME_CERT_${i} empty. Not checking any more."
            break
        fi

        log "Processing ${var_name}: '${value}'"

        if [[ "${value}" == *,* ]]; then
            log "Found multi-SAN certificate."
            multi_san_cert $value
        else
            log "Found single-SAN certificate."
            single_san_cert $value
        fi

        ((i++))
    done

    log "Restricting permissions on ACME data directories."
    chmod 700 "${LE_CONFIG_HOME}" "${CERT_HOME}" 2>/dev/null || true

    setup_crontab

    log "Starting supercronic in background."
    supercronic -passthrough-logs "${CRONTAB_FILE}" &
}

check_env_vars_exist() {
    local missing=0
    for var in ACME_EMAIL CF_Token CF_Account_ID ACME_CERT_1; do
        if [ -z "${!var:-}" ]; then
            log "Required env var '${var}' is not set (required when ACME_AUTO_CERT_ENABLED=true)."
            missing=1
        fi
    done
    if [ "${missing}" -eq 1 ]; then
        exit 1
    fi
}

single_san_cert() {
    local domain=$1

    if [ ! -d "${CERT_HOME}/${domain}_ecc" ] && [ ! -d "${CERT_HOME}/${domain}" ]; then
        log "Cert for ${domain} does not exist yet, issuing certificate."
        acme.sh --issue \
            --server "${ACME_SERVER}" \
            -d ${domain} \
            --days ${ACME_RENEWAL_DAY} \
            --dns dns_cf \
            --renew-hook "nginx -s reload"
    else
        log "Certificate for '${domain}' already exists — skipping."
    fi
}

multi_san_cert() {
    local domains_csv="$1"
    local domain_args=""

    IFS=',' read -ra san_array <<< "${domains_csv}"
    local primary="${san_array[0]}"

    if [ ! -d "${CERT_HOME}/${primary}_ecc" ] && [ ! -d "${CERT_HOME}/${primary}" ]; then
        log "Multi-SAN certificate for '${primary}' not found — issuing."
        for san in "${san_array[@]}"; do
            domain_args="${domain_args}-d ${san} "
        done

        acme.sh --issue \
            --server "${ACME_SERVER}" \
            ${domain_args} \
            --days "${ACME_RENEWAL_DAY}" \
            --dns dns_cf \
            --renew-hook "nginx -s reload"
    else
        log "Multi-SAN certificate for '${primary}' already exists — skipping."
    fi
}

setup_crontab() {
    if [ ! -f "${CRONTAB_FILE}" ]; then
        log "No crontab found — generating one."
        local timestamp
        timestamp=$(date -u "+%s")
        local random_minute=$(( timestamp % 60 ))
        local random_hour=$(( timestamp / 60 % 24 ))
        echo "${random_minute} ${random_hour} * * * acme.sh --cron" > "${CRONTAB_FILE}"
        log "Renewal scheduled daily at $(printf '%02d:%02d' $random_hour $random_minute) UTC."
    else
        log "Existing crontab found — using it."
    fi
}

# log to stdout
log() {
    local message=$1
    echo "[$(date)] ENTRYPOINT: ${message}"
}

main
