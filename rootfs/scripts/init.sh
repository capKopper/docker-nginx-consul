#!/bin/bash
set -e

# set the DEBUG env variable to turn on debugging
[[ -n "$DEBUG" ]] && set -x

# Required vars
NGINX_KV=${NGINX_KV:-nginx/template/default}
CONSUL_LOGLEVEL=${CONSUL_LOGLEVEL:-debug}
NGINX_USER=${NGINX_USER:-nginx}
NGINX_USER_UID=${NGINX_USER_UID:-104}

export NGINX_KV
export NGINX_USER


# load library
source /scripts/logging.lib.sh

function usage(){
cat <<USAGE
  init.sh               Start a consul-backed nginx instance

Configure using the following environment variables:

Nginx vars:
  NGINX_KV                      Consul K/V path to template contents
                                (default nginx/template/default)

  NGINX_DEBUG                   If set, run consul-template once and check generated nginx.conf
                                (default not set)

  NGINX_USER                    User that runs nginx workers processes.
                                (default nginx)

  NGINX_USER_UID                The uid of the nginx user.
                                (default 104)

Consul vars:
  CONSUL_LOGLEVEL               Set the consul-templat  e log level
                                (default debug)

  CONSUL_CONNECT                URI for Consul agent
                                (default not set)

Checks vars:
  CHECK_CONSUL_CONNECT          Check if the Consul agent is available
                                (default not set)

  CHECK_CONSUL_CONNECT_TIMEOUT  Consul agent connection check timeout in seconds
                                (default 120)

  CHECK_NGINX_KV                Check if the NGINX_KV exists
                                (default not set)

  CHECK_NGINX_KV_TIMEOUT        NGINX_KV check timeout in seconds
                                (default 60)
USAGE
}

function check_consul_connect {
    if [ -n "${CHECK_CONSUL_CONNECT}" ]; then
        _log "Checking if Consul ($CONSUL_CONNECT) is up..."
        MAX_SECONDS=${CHECK_CONSUL_CONNECT_TIMEOUT:-120}
        until curl -s --fail --max-time 1 -o /dev/null "http://${CONSUL_CONNECT}/v1/status/leader"; do
            sleep 1
            [[ "$SECONDS" -ge "$MAX_SECONDS" ]] && _error "Consul not responding after $MAX_SECONDS seconds ($CONSUL_CONNECT)"
        done
        _debug "connection ok"
    fi
}

function check_nginx_kv {
    if [ -n "${CHECK_NGINX_KV}" ]; then
        _log "Checking if the NGINX_KV ($NGINX_KV) exists..."
        MAX_SECONDS=${CHECK_NGINX_KV_TIMEOUT:-60}
        until curl -s --fail --show-error -o /dev/null "http://${CONSUL_CONNECT}/v1/kv/${NGINX_KV}"; do
            sleep 1
            [[ "$SECONDS" -ge "$MAX_SECONDS" ]] && _error "$NGINX_KV doesn't exists. Exiting."
        done
        _debug "key found"
    fi
}

function check_user {
    _log "Checking that '$NGINX_USER' user exists..."
    if [ $(grep -c $NGINX_USER /etc/passwd) == "0" ]; then
        _debug "create user '$NGINX_USER' with uid '$NGINX_USER_UID'"
        useradd -u $NGINX_USER_UID -s /bin/false -d /nohome $NGINX_USER
    else
        _debug "user exists"
    fi
}

function do_checks {
    check_user
    check_consul_connect
    check_nginx_kv
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

    # Do some checks
    do_checks

    # Create an empty nginx.conf.tmpl so consul-template will start
    touch /consul-template/templates/nginx.conf.ctmpl

    if [ -n "${NGINX_DEBUG}" ]; then
        _log "Starting consul-template in ONCE mode..."
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
        consul-template -log-level ${CONSUL_LOGLEVEL} \
                        -template /consul-template/templates/nginx.conf.ctmpl.in:/consul-template/templates/nginx.conf.ctmpl \
                        ${ctargs} -once

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