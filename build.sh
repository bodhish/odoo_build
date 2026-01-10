#!/bin/bash
# Build script for Odoo Enterprise base image
#
# Usage:
#   ./build.sh                              # Uses .env file
#   ./build.sh https://s3-url/odoo.tar.gz   # Direct URL
#   ODOO_SOURCE_URL=... ./build.sh          # Environment variable

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load .env file if it exists
if [ -f .env ]; then
    echo "Loading configuration from .env file..."
    export $(grep -v '^#' .env | xargs)
fi

# Override with command line argument if provided
if [ -n "$1" ]; then
    ODOO_SOURCE_URL="$1"
fi

# Validate required variables
if [ -z "$ODOO_SOURCE_URL" ]; then
    echo "ERROR: ODOO_SOURCE_URL is required"
    echo ""
    echo "Usage:"
    echo "  1. Copy env.example to .env and set ODOO_SOURCE_URL"
    echo "  2. Run: ./build.sh"
    echo ""
    echo "Or:"
    echo "  ./build.sh https://your-s3-url/odoo.tar.gz"
    exit 1
fi

# Set defaults
IMAGE_NAME="${IMAGE_NAME:-odoo-enterprise}"
IMAGE_TAG="${IMAGE_TAG:-19.0}"
ODOO_VERSION="${ODOO_VERSION:-19.0}"
ODOO_RELEASE="${ODOO_RELEASE:-20260106}"

echo "============================================"
echo "Building Odoo Enterprise Base Image"
echo "============================================"
echo "Source URL: $ODOO_SOURCE_URL"
echo "Image: $IMAGE_NAME:$IMAGE_TAG"
echo "Version: $ODOO_VERSION"
echo "Release: $ODOO_RELEASE"
echo "============================================"

docker build \
    --build-arg ODOO_SOURCE_URL="$ODOO_SOURCE_URL" \
    --build-arg ODOO_VERSION="$ODOO_VERSION" \
    --build-arg ODOO_RELEASE="$ODOO_RELEASE" \
    -t "$IMAGE_NAME:$IMAGE_TAG" \
    -t "$IMAGE_NAME:latest" \
    .

echo ""
echo "============================================"
echo "Build complete!"
echo "============================================"
echo "Image: $IMAGE_NAME:$IMAGE_TAG"
echo ""
echo "Use as base image in your Dockerfile:"
echo "  FROM $IMAGE_NAME:$IMAGE_TAG"
echo ""
echo "============================================"
