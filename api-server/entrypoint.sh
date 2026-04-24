#!/bin/sh
set -e

# Use positional parameters to safely build the command. This avoids issues with
# word splitting if variables contain spaces or special characters.
set -- ./api-server -port "${PORT}"
# Add TLS configuration if provided
if [ -n "${CERT_FILE}" ] && [ -n "${KEY_FILE}" ]; then
    set -- "$@" -cert "${CERT_FILE}" -key "${KEY_FILE}"
fi
exec "$@"
