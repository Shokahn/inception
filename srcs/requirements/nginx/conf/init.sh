#!/bin/bash

# Generate a self-signed TLS certificate if one doesn't exist yet
if [ ! -f /etc/ssl/certs/inception.crt ]; then
    openssl req -x509 -nodes -newkey rsa:2048 \
        -keyout /etc/ssl/private/inception.key \
        -out    /etc/ssl/certs/inception.crt \
        -days   365 \
        -subj   "/C=FR/ST=IDF/L=Paris/O=42/CN=${DOMAIN_NAME}"
fi

exec nginx -g "daemon off;"
