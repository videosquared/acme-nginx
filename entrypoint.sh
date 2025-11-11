#!/usr/bin/env bash

main() {
    ACME_HOME="/opt/acme" # MUST NOT have trailing slash
    ACME_CERT_DIR="/etc/ssl/acme" # MUST NOT have trailing slash
    ACME_SERVER="${ACME_SERVER:-letsencrypt}"
    ACME_SLEEP="${ACME_SLEEP:-86400}" # Sleep in seconds 1 day = 86400s

    ACME_RENEWAL_DAY="${ACME_RENEWAL_DAY:-70}"

    check_env_vars_exist

    DEFAULT_ARGS="--home ${ACME_HOME} --server ${ACME_SERVER}"

    log "Trying to register account."
    ${ACME_HOME}/acme.sh --register-account ${DEFAULT_ARGS} -m ${ACME_EMAIL}

    i=1
    while true; do 
        var_name="ACME_CERT_${i}"
        value="${!var_name:-}"

        log "Checking ${var_name}."

        if [ -z $value ]; then
            log "ACME_CERT_${i} empty. Not checking any more."
            break
        fi

        if [ $value == *,* ]; then
            log "Found multi SAN certificate."
            multi_san_cert $value
            continue
        else 
            log "Found single SAN certificate."
            single_san_cert $value
        fi

        ((i++))
    done

    log "Starting nginx"
    nginx 

    log "Certificate generation done, going to start the cron job now."

    while true; do
        ${ACME_HOME}/acme.sh --cron --home ${ACME_HOME}
        log "Sleeping for ${ACME_SLEEP} seconds."
        sleep ${ACME_SLEEP}
    done
}

check_env_vars_exist() {

    if [ -z "${ACME_EMAIL}" ]; then
        log "Env var: ACME_EMAIL must be set."
        exit 1
    fi

    if [ -z "${CF_Token}" ]; then
        log "Env var: CF_Token must be set."
        exit 1
    fi

    if [ -z "${CF_Account_ID}" ]; then
        log "Env var: CF_Account_ID must be set."
        exit 1
    fi

    if [ -z "${ACME_CERT_1}" ]; then
        log "Atleast one certificate must be configured via the ACME_CERT_1 environment variable"
        exit 1
    fi
}

single_san_cert() {
    local domain=$1

    if [ ! -d "${ACME_CERT_DIR}/${domain}_ecc" ] && [ ! -d "${ACME_CERT_DIR}/${domain}" ]; then
        log "Cert for ${domain} does not exist yet, issuing certificate."
        ${ACME_HOME}/acme.sh --issue ${DEFAULT_ARGS} -d ${domain} --days ${ACME_RENEWAL_DAY} --dns dns_cf --renew-hook "nginx -s reload"
    fi
}

multi_san_cert() {
    local domains=$1
    local domain_args=""

    IFS=',' read -a array <<< "$domains"

    log "Generating multi-san certificate"
    if [ ! -d "${ACME_CERT_DIR}/${domains[0]}_ecc" ] && [ ! -d "${ACME_CERT_DIR}/${domain[0]}" ]; then
        for san in "${domains[@]}"
        do 
            domain_args="${domain_args}-d ${san} "
        done

        ${ACME_HOME}/acme.sh --issue ${DEFAULT_ARGS} ${domain_args} --days ${ACME_RENEWAL_DAY} --dns dns_cf --renew-hook "nginx -s reload"
    fi 
}

log() {
    local message=$1

    echo "[$(date)] MY_ACME_LOG: ${message}"
}

main
