#!/bin/bash

# HTTPS Server Startup Script
# This script starts the API server with HTTPS using Let's Encrypt certificates

# Configuration
DOMAIN="${DOMAIN:-yourdomain.com}"  # Set this to your actual domain or use environment variable
PORT="${PORT:-8443}"
CERT_DIR="../mail-infra/services/silver-config/certbot/keys/etc/live/${DOMAIN}"

# Certificate paths
CERT_FILE="${CERT_DIR}/fullchain.pem"
KEY_FILE="${CERT_DIR}/privkey.pem"

# Check if certificates exist
if [ ! -f "$CERT_FILE" ]; then
    echo "Error: Certificate file not found at $CERT_FILE"
    echo "Please ensure Let's Encrypt certificates are generated for domain: $DOMAIN"
    exit 1
fi

if [ ! -f "$KEY_FILE" ]; then
    echo "Error: Key file not found at $KEY_FILE"
    echo "Please ensure Let's Encrypt certificates are generated for domain: $DOMAIN"
    exit 1
fi

echo "Starting HTTPS server on port $PORT"
echo "Domain: $DOMAIN"
echo "Certificate: $CERT_FILE"
echo "Key: $KEY_FILE"
echo ""

# Start the server
go run . -port "$PORT" -cert "$CERT_FILE" -key "$KEY_FILE"
