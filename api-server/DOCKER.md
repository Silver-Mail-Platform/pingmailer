# Docker Deployment Guide

This guide explains how to build and run the API server using Docker.

## Quick Start

### Option 1: HTTP Mode (Development)

```bash
# Build and run with docker-compose
docker-compose up -d

# Or build and run manually
docker build -t pingmailer-api .
docker run -d -p 8080:8080 --name pingmailer-api pingmailer-api
```

### Option 2: HTTPS Mode (Production)

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
  -e CERT_FILE=/certs/fullchain.pem \
  -e KEY_FILE=/certs/privkey.pem \
  -v $(pwd)/../mail-infra/services/silver-config/certbot/keys/etc/live/aravindahwk.org:/certs:ro \
  --network mail-network \
  pingmailer-api
```

## Docker Commands Reference

### Build Image

```bash
# Build with default tag
docker build -t pingmailer-api .

# Build with version tag
docker build -t pingmailer-api:1.0.0 .

# Build with no cache
docker build --no-cache -t pingmailer-api .
```

### Run Container

```bash
# Run in HTTP mode
docker run -d -p 8080:8080 --name pingmailer-api pingmailer-api

# Run in HTTPS mode
docker run -d \
  -p 8443:8443 \
  -e PORT=8443 \
  -e CERT_FILE=/certs/fullchain.pem \
  -e KEY_FILE=/certs/privkey.pem \
  -v /path/to/certs:/certs:ro \
  --name pingmailer-api \
  pingmailer-api

# Run with custom port
docker run -d -p 9000:9000 -e PORT=9000 --name pingmailer-api pingmailer-api
```

### View Logs

```bash
# View logs
docker logs pingmailer-api

# Follow logs
docker logs -f pingmailer-api

# View last 100 lines
docker logs --tail 100 pingmailer-api
```

### Manage Container

```bash
# Stop container
docker stop pingmailer-api

# Start container
docker start pingmailer-api

# Restart container
docker restart pingmailer-api

# Remove container
docker rm -f pingmailer-api

# Remove image
docker rmi pingmailer-api
```

### Inspect Container

```bash
# Show container details
docker inspect pingmailer-api

# Show container stats
docker stats pingmailer-api

# Execute command in container
docker exec -it pingmailer-api sh

# Check if certificates are accessible
docker exec pingmailer-api ls -la /certs
```

## Docker Compose Commands

### Using default docker-compose.yml (HTTP)

```bash
# Start services
docker-compose up -d

# Stop services
docker-compose down

# View logs
docker-compose logs -f

# Rebuild and start
docker-compose up -d --build

# Remove everything including volumes
docker-compose down -v
```

### Using docker-compose.https.yml (HTTPS)

```bash
# Start HTTPS services
docker-compose -f docker-compose.https.yml up -d

# Stop HTTPS services
docker-compose -f docker-compose.https.yml down

# View logs
docker-compose -f docker-compose.https.yml logs -f

# Rebuild
docker-compose -f docker-compose.https.yml up -d --build
```

## Integration with Mail Infrastructure

To integrate the API server with the existing mail infrastructure:

### 1. Join the Mail Network

The mail infrastructure uses a Docker network called `mail-network`. Create it if it doesn't exist:

```bash
docker network create mail-network
```

Or check if it exists:

```bash
docker network ls | grep mail-network
```

### 2. Use docker-compose.https.yml

The `docker-compose.https.yml` file is already configured to join the mail network:

```bash
docker-compose -f docker-compose.https.yml up -d
```

### 3. Access from Other Containers

Other containers in the `mail-network` can access the API server using the container name:

```bash
# From another container in mail-network
curl -X POST https://pingmailer-api-server:8443/notify \
  -H "Content-Type: application/json" \
  -d '{"smtp_host":"smtp-server-container", ...}'
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `8080` | Port the server listens on |
| `CERT_FILE` | (empty) | Path to TLS certificate file |
| `KEY_FILE` | (empty) | Path to TLS private key file |

## Volume Mounts

### For HTTPS Mode

Mount the Let's Encrypt certificates directory:

```yaml
volumes:
  - /path/to/certbot/keys/etc/live/yourdomain.com:/certs:ro
```

The `:ro` flag mounts the volume as read-only for security.

## Testing the Deployment

### Test HTTP Endpoint

```bash
curl -X POST http://localhost:8080/notify \
  -H "Content-Type: application/json" \
  -d '{
    "smtp_host": "smtp.gmail.com",
    "smtp_port": 587,
    "smtp_username": "your-email@gmail.com",
    "smtp_password": "your-password",
    "smtp_sender": "noreply@example.com",
    "recipient_email": "recipient@example.com",
    "recipient_name": "Test User",
    "app_name": "Test App"
  }'
```

### Test HTTPS Endpoint

```bash
curl -k -X POST https://localhost:8443/notify \
  -H "Content-Type: application/json" \
  -d '{
    "smtp_host": "smtp-server-container",
    "smtp_port": 587,
    "smtp_username": "user@aravindahwk.org",
    "smtp_password": "password",
    "smtp_sender": "noreply@aravindahwk.org",
    "recipient_email": "test@example.com",
    "recipient_name": "Test User",
    "app_name": "PingMailer"
  }'
```

Note: `-k` flag skips certificate verification. For production, use proper certificate verification.

## Troubleshooting

### Container Won't Start

```bash
# Check container logs
docker logs pingmailer-api

# Check if port is already in use
netstat -tulpn | grep 8443
# or
lsof -i :8443
```

### Certificate Errors

```bash
# Verify certificate files exist
docker exec pingmailer-api ls -la /certs

# Check certificate permissions
ls -la ../mail-infra/services/silver-config/certbot/keys/etc/live/aravindahwk.org/

# Verify certificate contents
docker exec pingmailer-api cat /certs/fullchain.pem
```

### Network Issues

```bash
# Check if container is on the network
docker network inspect mail-network

# Check if container can reach other services
docker exec -it pingmailer-api ping smtp-server-container
```

### Build Failures

```bash
# Clean build cache
docker builder prune

# Rebuild without cache
docker build --no-cache -t pingmailer-api .

# Check Go dependencies
docker run --rm -v $(pwd):/app -w /app golang:1.23-alpine go mod verify
```

## Production Deployment

### Using with Reverse Proxy (nginx/Traefik)

If using a reverse proxy, you can run the API server in HTTP mode internally and let the proxy handle HTTPS:

```yaml
services:
  api-server:
    # ... other config
    ports:
      - "127.0.0.1:8080:8080"  # Only expose to localhost
    networks:
      - internal
      - proxy
```

### Health Checks

Add health checks to docker-compose.yml:

```yaml
services:
  api-server:
    # ... other config
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
```

Note: You'll need to implement a `/health` endpoint in the application.

### Resource Limits

Set resource limits for production:

```yaml
services:
  api-server:
    # ... other config
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 256M
        reservations:
          cpus: '0.25'
          memory: 128M
```

## Security Best Practices

1. **Run as non-root**: The Dockerfile already creates and uses a non-root user
2. **Read-only certificates**: Mount certificate volumes with `:ro` flag
3. **Network isolation**: Use Docker networks to isolate services
4. **Scan images**: Regularly scan images for vulnerabilities
   ```bash
   docker scan pingmailer-api
   ```
5. **Keep images updated**: Rebuild regularly to get security updates
6. **Use secrets**: For production, use Docker secrets instead of environment variables for sensitive data

## Updating the Application

```bash
# Pull latest code
git pull

# Rebuild and restart
docker-compose -f docker-compose.https.yml up -d --build

# Or with manual docker
docker build -t pingmailer-api .
docker stop pingmailer-api
docker rm pingmailer-api
docker run -d [your run options] pingmailer-api
```

## Backup and Restore

The API server is stateless, so no backup is needed. However, ensure you have:

1. Source code in version control
2. Certificate backups
3. Documentation of environment variables and configuration
