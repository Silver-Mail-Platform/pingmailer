#!/bin/bash

# Certificate Path Verification Script
# This script helps verify that certificate paths are correct before running Docker

echo "========================================"
echo "Certificate Path Verification"
echo "========================================"
echo ""

# Configuration
DOMAIN="${DOMAIN:-aravindahwk.org}"
CERT_BASE_PATH="../mail-infra/services/silver-config/certbot/keys/etc/live/${DOMAIN}"

echo "Domain: $DOMAIN"
echo "Certificate base path: $CERT_BASE_PATH"
echo ""

# Check if base directory exists
if [ -d "$CERT_BASE_PATH" ]; then
    echo "✓ Certificate directory exists: $CERT_BASE_PATH"
else
    echo "✗ Certificate directory NOT found: $CERT_BASE_PATH"
    echo ""
    echo "Available domains in certbot:"
    CERT_LIVE_PATH="../mail-infra/services/silver-config/certbot/keys/etc/live"
    if [ -d "$CERT_LIVE_PATH" ]; then
        ls -1 "$CERT_LIVE_PATH"
    else
        echo "Certbot live directory not found at: $CERT_LIVE_PATH"
    fi
    exit 1
fi

echo ""
echo "Certificate files:"

# Check fullchain.pem
if [ -f "$CERT_BASE_PATH/fullchain.pem" ]; then
    echo "✓ fullchain.pem exists"
    ls -lh "$CERT_BASE_PATH/fullchain.pem"
else
    echo "✗ fullchain.pem NOT found"
fi

# Check privkey.pem
if [ -f "$CERT_BASE_PATH/privkey.pem" ]; then
    echo "✓ privkey.pem exists"
    ls -lh "$CERT_BASE_PATH/privkey.pem"
else
    echo "✗ privkey.pem NOT found"
fi

# Check cert.pem
if [ -f "$CERT_BASE_PATH/cert.pem" ]; then
    echo "✓ cert.pem exists"
    ls -lh "$CERT_BASE_PATH/cert.pem"
fi

# Check chain.pem
if [ -f "$CERT_BASE_PATH/chain.pem" ]; then
    echo "✓ chain.pem exists"
    ls -lh "$CERT_BASE_PATH/chain.pem"
fi

echo ""
echo "All files in certificate directory:"
ls -la "$CERT_BASE_PATH/"

echo ""
echo "========================================"
echo "Verification complete!"
echo "========================================"

# Provide next steps
if [ -f "$CERT_BASE_PATH/fullchain.pem" ] && [ -f "$CERT_BASE_PATH/privkey.pem" ]; then
    echo ""
    echo "✓ All required certificates found!"
    echo ""
    echo "You can now run:"
    echo "  docker compose -f docker-compose.https.yml up -d"
else
    echo ""
    echo "✗ Some certificates are missing. Please ensure certbot has generated certificates."
fi
