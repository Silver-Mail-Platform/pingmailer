#!/bin/sh
set -e

# Use positional parameters to safely build the command. This avoids issues with
# word splitting if variables contain spaces or special characters.
set -- ./api-server -port "${PORT}"
# Add OAuth2 introspection URL
if [ -n "${OAUTH2_INTROSPECT_URL}" ]; then
    set -- "$@" -oauth2-introspect-url "${OAUTH2_INTROSPECT_URL}"
else
    echo "Error: OAUTH2_INTROSPECT_URL must be set" >&2
    exit 1
fi
# Add TLS configuration if provided
if [ -n "${CERT_FILE}" ] && [ -n "${KEY_FILE}" ]; then
    set -- "$@" -cert "${CERT_FILE}" -key "${KEY_FILE}"
fi
exec "$@"
