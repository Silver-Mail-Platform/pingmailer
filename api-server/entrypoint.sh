#!/bin/sh
set -e

# Build command with OAuth2 parameters
CMD="./api-server -port ${PORT}"

# Add OAuth2 configuration
if [ -n "$OAUTH2_CLIENT_ID" ] && [ -n "$OAUTH2_CLIENT_SECRET" ]; then
    CMD="$CMD -oauth2-client-id ${OAUTH2_CLIENT_ID} -oauth2-client-secret ${OAUTH2_CLIENT_SECRET}"
    
    if [ -n "$OAUTH2_TOKEN_URL" ]; then
        CMD="$CMD -oauth2-token-url ${OAUTH2_TOKEN_URL}"
    fi
else
    echo "Error: OAUTH2_CLIENT_ID and OAUTH2_CLIENT_SECRET must be set"
    exit 1
fi

# Add TLS configuration if provided
if [ -n "$CERT_FILE" ] && [ -n "$KEY_FILE" ]; then
    CMD="$CMD -cert ${CERT_FILE} -key ${KEY_FILE}"
fi

exec $CMD
