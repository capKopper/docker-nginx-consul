#!/bin/bash
[ -f /var/run/nginx.pid ] && kill -USR1 `cat /var/run/nginx.pid`