#!/bin/bash
set -e

# set the DEBUG env variable to turn on debugging
[[ -n "$DEBUG" ]] && set -x

# Required vars
NGINX_KV=${NGINX_KV:-nginx/template/default}
CONSUL_LOGLEVEL=${CONSUL_LOGLEVEL:-debug}

export NGINX_KV


# load library
source /scripts/logging.lib.sh

function usage(){
cat <<USAGE
  init.sh               Start a consul-backed nginx instance

Configure using the following environment variables:

Nginx vars:
  NGINX_KV              Consul K/V path to template contents
                        (default nginx/template/default)

  NGINX_DEBUG           If set, run consul-template once and check generated nginx.conf
                        (default not set)

Consul vars:
  CONSUL_LOGLEVEL      Set the consul-template log level
                        (default debug)

  CONSUL_CONNECT        URI for Consul agent
                        (default not set)
USAGE
}

function launch_consul_template {
    vars=$@
    ctargs=

    # Check if CONSUL_CONNECT is set
    if [ -z "${CONSUL_CONNECT}" ]; then
        _error "CONSUL_CONNECT environment variable is not set. Exiting."
    else
        ctargs="${ctargs} -consul ${CONSUL_CONNECT}"
    fi

    # Create an empty nginx.conf.tmpl so consul-template will start
    touch /consul-template/templates/nginx.conf.ctmpl

    if [ -n "${NGINX_DEBUG}" ]; then
        _log "Starting consul-template -once..."
        consul-template -log-level ${CONSUL_LOGLEVEL} \
                        -template /consul-template/templates/nginx.conf.ctmpl.in:/consul-template/templates/nginx.conf.ctmpl \
                        ${ctargs} -once

        consul-template -log-level ${CONSUL_LOGLEVEL} \
                        -template /consul-template/templates/nginx.conf.ctmpl:/etc/nginx/nginx.conf \
                        ${ctargs} -once ${vars}

        cat /etc/nginx/nginx.conf && \
        /usr/sbin/nginx -t -c /etc/nginx/nginx.conf

    else
        _log "Starting consul-template..."
        exec consul-template -log-level ${CONSUL_LOGLEVEL} \
                             -config /consul-template/config \
                             ${ctargs} ${vars}
    fi
}

function main() {
    if [ "$1" == "-h" ]; then
        usage
        exit 0
    else
        launch_consul_template $@
    fi
}


main $@