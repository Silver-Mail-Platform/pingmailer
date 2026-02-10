# Multi-stage build for optimal image size
# Stage 1: Build the Go application
FROM golang:alpine AS builder

# Install build dependencies
RUN apk add --no-cache git ca-certificates tzdata

# Set GOTOOLCHAIN to auto to allow newer go versions
ENV GOTOOLCHAIN=auto

# Set working directory
WORKDIR /build

# Copy go mod files and download dependencies
COPY go.mod go.sum ./
RUN go mod download

# Copy the entire source code
COPY . .

# Build the application
# CGO_ENABLED=0 for static binary, GOOS=linux for Linux systems
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -ldflags="-w -s" -o api-server .

# Stage 2: Create the final minimal image
FROM alpine:latest

# Install ca-certificates for HTTPS requests
RUN apk --no-cache add ca-certificates tzdata

# Create a non-root user
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser

# Set working directory
WORKDIR /app

# Copy the binary from builder
COPY --from=builder /build/api-server .

# Copy templates directory (needed for email templates)
COPY --from=builder /build/internal/emailer/templates ./internal/emailer/templates

# Create directory for certificates (will be mounted as volume)
RUN mkdir -p /certs && chown appuser:appuser /certs

# Change ownership of the app directory
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Expose ports
# 8080 for HTTP, 8443 for HTTPS
EXPOSE 8080 8443

# Set environment variables (can be overridden)
ENV PORT=8080
ENV CERT_FILE=""
ENV KEY_FILE=""

# Default command - runs HTTP mode
# To run with HTTPS, override CMD or set environment variables
CMD if [ -n "$CERT_FILE" ] && [ -n "$KEY_FILE" ]; then \
        ./api-server -port ${PORT} -cert ${CERT_FILE} -key ${KEY_FILE}; \
    else \
        ./api-server -port ${PORT}; \
    fi
