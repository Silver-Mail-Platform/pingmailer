#!/bin/sh
set -e

if [ -n "$CERT_FILE" ] && [ -n "$KEY_FILE" ]; then
    exec ./api-server -port "${PORT}" -cert "${CERT_FILE}" -key "${KEY_FILE}"
else
    exec ./api-server -port "${PORT}"
fi
