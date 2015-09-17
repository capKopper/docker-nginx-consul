#!/bin/bash
source /scripts/logging.lib.sh

_log "Removing blank lines from nginx.conf..."
sed -i -e 's/^#.*$//g' -e '/^[[:space:]]*$/d' /etc/nginx/nginx.conf

/usr/sbin/nginx -s reload
if [ $? -eq 0 ]; then
  _log "Reloading nginx..."
  exit 0
fi

_log "Checking nginx.conf..."
/usr/sbin/nginx -t -c /etc/nginx/nginx.conf
if [ $? -ne 0 ]; then
  _error "nginx.conf check failed..."
fi

_log "Starting nginx..."
/usr/sbin/nginx -c /etc/nginx/nginx.conf
exit $?