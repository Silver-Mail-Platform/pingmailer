# Quick Start - Docker Deployment

This is a quick reference for deploying the API server with Docker.

## 🚀 Quick Deploy

### HTTP Mode (Development)
```bash
./docker-deploy.sh
```

### HTTPS Mode (Production)
```bash
DOMAIN=aravindahwk.org MODE=https ./docker-deploy.sh
```

## 📋 Files Overview

| File | Purpose |
|------|---------|
| `Dockerfile` | Multi-stage build configuration for creating optimized container image |
| `docker-compose.yml` | HTTP mode deployment configuration |
| `docker-compose.https.yml` | HTTPS/production deployment configuration |
| `docker-deploy.sh` | Automated deployment script |
| `.dockerignore` | Files to exclude from Docker build |
| `DOCKER.md` | Complete Docker documentation |

## 🔧 Common Commands

```bash
# Build image
make docker-build

# Run HTTP
make docker-run

# Run HTTPS  
make docker-run-https

# Use docker-compose
make docker-compose-up          # HTTP
make docker-compose-https       # HTTPS

# View logs
make docker-logs

# Stop and clean
make docker-stop
make docker-clean
```

## 📦 What's Included

The Docker image includes:
- ✅ Multi-stage build for minimal image size (~15MB)
- ✅ Non-root user for security
- ✅ Alpine Linux base for small footprint
- ✅ Built-in HTTPS/TLS support
- ✅ Email templates embedded
- ✅ Health check ready
- ✅ Network integration with mail infrastructure

## 🔒 HTTPS Setup

1. Ensure certificates exist:
   ```bash
   ls -la ../mail-infra/services/silver-config/certbot/keys/etc/live/aravindahwk.org/
   ```

2. Update domain in `docker-compose.https.yml`

3. Deploy:
   ```bash
   DOMAIN=aravindahwk.org MODE=https ./docker-deploy.sh
   ```

## 🧪 Test Deployment

```bash
# HTTP
curl -X POST http://localhost:8080/notify -H "Content-Type: application/json" -d '{...}'

# HTTPS
curl -k -X POST https://localhost:8443/notify -H "Content-Type: application/json" -d '{...}'
```

## 📖 Full Documentation

See [DOCKER.md](DOCKER.md) for complete documentation including:
- Detailed deployment instructions
- Integration with mail infrastructure
- Production configuration
- Troubleshooting guide
- Security best practices
