# Docker Deployment Guide

This guide explains how to build and run the API server using Docker.

## Quick Start

### Option 1: HTTPS Mode (Production)

**Using docker-compose (Recommended):**

```bash
# 1. Update the domain name in docker-compose.https.yml
sed -i 's/yourdomain.com/aravindahwk.org/g' docker-compose.https.yml

# 2. Make sure the mail-network exists
docker network create mail-network

# 3. Start the service
docker-compose -f docker-compose.https.yml up -d
```

**Manual Docker run:**

```bash
# Build the image
docker build -t pingmailer-api .

# Run with HTTPS
docker run -d \
  --name pingmailer-api \
  -p 8443:8443 \
  -e PORT=8443 \
  -e CERT_FILE=/certs/live/yourdomain.co/fullchain.pem \
  -e KEY_FILE=/certs/live/yourdomain.co/privkey.pem \
  -v $(pwd)/../mail-infra/services/silver-config/certbot/keys/etc:/certs:ro \
  --network mail-network \
  pingmailer-api
```