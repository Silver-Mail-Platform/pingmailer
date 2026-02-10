#!/bin/bash

# Docker Deployment Script for PingMailer API Server
# This script helps deploy the API server with Docker

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
DOMAIN="${DOMAIN:-yourdomain.com}"
MODE="${MODE:-http}"
IMAGE_NAME="pingmailer-api"
CONTAINER_NAME="pingmailer-api"

echo "========================================="
echo "PingMailer API Server - Docker Deployment"
echo "========================================="
echo ""

# Function to print colored messages
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

print_success "Docker is installed"

# Check if docker-compose is installed
if ! command -v docker-compose &> /dev/null; then
    print_info "docker-compose is not installed. Will use manual Docker commands."
    USE_COMPOSE=false
else
    print_success "docker-compose is installed"
    USE_COMPOSE=true
fi

# Build the image
echo ""
print_info "Building Docker image..."
if docker build -t $IMAGE_NAME .; then
    print_success "Docker image built successfully"
else
    print_error "Failed to build Docker image"
    exit 1
fi

# Stop and remove existing container if it exists
if docker ps -a | grep -q $CONTAINER_NAME; then
    print_info "Stopping existing container..."
    docker stop $CONTAINER_NAME > /dev/null 2>&1 || true
    docker rm $CONTAINER_NAME > /dev/null 2>&1 || true
    print_success "Existing container removed"
fi

echo ""
echo "Deployment mode: $MODE"
echo "Domain: $DOMAIN"
echo ""

# Deploy based on mode
if [ "$MODE" = "https" ]; then
    # HTTPS mode
    CERT_DIR="../mail-infra/services/silver-config/certbot/keys/etc/live/${DOMAIN}"
    
    # Check if certificates exist
    if [ ! -d "$CERT_DIR" ]; then
        print_error "Certificate directory not found: $CERT_DIR"
        print_info "Please ensure Let's Encrypt certificates are generated for domain: $DOMAIN"
        exit 1
    fi
    
    if [ ! -f "$CERT_DIR/fullchain.pem" ] || [ ! -f "$CERT_DIR/privkey.pem" ]; then
        print_error "Certificate files not found in: $CERT_DIR"
        exit 1
    fi
    
    print_success "Certificates found"
    
    # Check if mail-network exists
    if ! docker network ls | grep -q mail-network; then
        print_info "Creating mail-network..."
        docker network create mail-network
        print_success "Network created"
    fi
    
    if [ "$USE_COMPOSE" = true ]; then
        # Update domain in docker-compose.https.yml
        print_info "Updating docker-compose.https.yml with domain: $DOMAIN"
        sed -i.bak "s/yourdomain.com/$DOMAIN/g" docker-compose.https.yml
        
        print_info "Starting with docker-compose..."
        docker-compose -f docker-compose.https.yml up -d
    else
        # Manual docker run
        print_info "Starting container with HTTPS..."
        docker run -d \
            -p 8443:8443 \
            -e PORT=8443 \
            -e CERT_FILE=/certs/fullchain.pem \
            -e KEY_FILE=/certs/privkey.pem \
            -v "$(pwd)/${CERT_DIR}:/certs:ro" \
            --network mail-network \
            --name $CONTAINER_NAME \
            --restart unless-stopped \
            $IMAGE_NAME
    fi
    
    print_success "API server started in HTTPS mode on port 8443"
    echo ""
    print_info "Test with: curl -k -X POST https://${DOMAIN}:8443/notify ..."
    
else
    # HTTP mode
    if [ "$USE_COMPOSE" = true ]; then
        print_info "Starting with docker-compose..."
        docker-compose up -d
    else
        print_info "Starting container with HTTP..."
        docker run -d \
            -p 8080:8080 \
            --name $CONTAINER_NAME \
            --restart unless-stopped \
            $IMAGE_NAME
    fi
    
    print_success "API server started in HTTP mode on port 8080"
    echo ""
    print_info "Test with: curl -X POST http://localhost:8080/notify ..."
fi

echo ""
print_info "View logs with: docker logs -f $CONTAINER_NAME"
print_info "Stop with: docker stop $CONTAINER_NAME"
echo ""
print_success "Deployment complete!"
