#!/bin/sh
set -eu

SOCKET=/run/fcgiwrap.socket
APP_USER=nginx

rm -f "$SOCKET"

spawn-fcgi -s "$SOCKET" -M 0770 -u "$APP_USER" -g "$APP_USER" -- /usr/bin/fcgiwrap

# wait for the socket to actually appear before continuing
for i in $(seq 1 20); do
    [ -S "$SOCKET" ] && break
    sleep 0.1
done

if [ ! -S "$SOCKET" ]; then
    echo "ERROR: fcgiwrap socket never appeared at $SOCKET" >&2
    exit 1
fi

chown "$APP_USER":"$APP_USER" "$SOCKET"
chmod 0770 "$SOCKET"

chmod 755 -R /repos
chown -R "$APP_USER":"$APP_USER" /repos

git config --global safe.directory "*"

exec nginx -g "daemon off;"
