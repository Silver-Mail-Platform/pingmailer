#!/bin/sh
set -e

# Build command with OAuth2 parameters
CMD="./api-server -port ${PORT}"

# Add OAuth2 introspection URL
if [ -n "$OAUTH2_INTROSPECT_URL" ]; then
    CMD="$CMD -oauth2-introspect-url ${OAUTH2_INTROSPECT_URL}"
else
    echo "Error: OAUTH2_INTROSPECT_URL must be set"
    exit 1
fi

# Add TLS configuration if provided
if [ -n "$CERT_FILE" ] && [ -n "$KEY_FILE" ]; then
    CMD="$CMD -cert ${CERT_FILE} -key ${KEY_FILE}"
fi

exec $CMD
