#!/bin/bash
# Build script for Odoo Enterprise base image
#
# Usage:
#   ./build.sh                              # Uses .env file
#   ./build.sh https://s3-url/odoo.tar.gz   # Direct URL
#   ODOO_SOURCE_URL=... ./build.sh          # Environment variable
#   ./build.sh --no-cache                   # Force rebuild without cache
#   ./build.sh --check                      # Check if rebuild is needed (exit 0 if no changes)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Parse command line options
NO_CACHE=""
CHECK_ONLY=""
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-cache)
            NO_CACHE="--no-cache"
            shift
            ;;
        --check)
            CHECK_ONLY="true"
            shift
            ;;
        *)
            POSITIONAL_ARGS+=("$1")
            shift
            ;;
    esac
done

# Restore positional parameters
set -- "${POSITIONAL_ARGS[@]}"

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

# Function to check if image exists and matches current configuration
check_image_exists() {
    local image_id
    image_id=$(docker images -q "$IMAGE_NAME:$IMAGE_TAG" 2>/dev/null)
    
    if [ -z "$image_id" ]; then
        return 1  # Image doesn't exist
    fi
    
    # Check if build args match by inspecting labels (if set)
    local existing_version existing_release existing_url
    existing_version=$(docker inspect --format '{{index .Config.Labels "odoo.version"}}' "$IMAGE_NAME:$IMAGE_TAG" 2>/dev/null || echo "")
    existing_release=$(docker inspect --format '{{index .Config.Labels "odoo.release"}}' "$IMAGE_NAME:$IMAGE_TAG" 2>/dev/null || echo "")
    existing_url=$(docker inspect --format '{{index .Config.Labels "odoo.source_url"}}' "$IMAGE_NAME:$IMAGE_TAG" 2>/dev/null || echo "")
    
    if [ "$existing_version" = "$ODOO_VERSION" ] && \
       [ "$existing_release" = "$ODOO_RELEASE" ] && \
       [ "$existing_url" = "$ODOO_SOURCE_URL" ]; then
        return 0  # Image exists and matches
    fi
    
    return 1  # Image exists but configuration differs
}

# Check-only mode: exit with status indicating if rebuild is needed
if [ "$CHECK_ONLY" = "true" ]; then
    echo "Checking if rebuild is needed..."
    if check_image_exists; then
        echo "No rebuild needed. Image $IMAGE_NAME:$IMAGE_TAG is up to date."
        echo "  Version: $ODOO_VERSION"
        echo "  Release: $ODOO_RELEASE"
        exit 0
    else
        echo "Rebuild needed. Image $IMAGE_NAME:$IMAGE_TAG does not exist or configuration has changed."
        exit 1
    fi
fi

# Check if we can skip the build (image already exists with same config)
if [ -z "$NO_CACHE" ] && check_image_exists; then
    echo "============================================"
    echo "Image already up to date!"
    echo "============================================"
    echo "Image $IMAGE_NAME:$IMAGE_TAG already exists with matching configuration."
    echo "  Version: $ODOO_VERSION"
    echo "  Release: $ODOO_RELEASE"
    echo ""
    echo "To force a rebuild, use: ./build.sh --no-cache"
    echo "============================================"
    exit 0
fi

echo "============================================"
echo "Building Odoo Enterprise Base Image"
echo "============================================"
echo "Source URL: $ODOO_SOURCE_URL"
echo "Image: $IMAGE_NAME:$IMAGE_TAG"
echo "Version: $ODOO_VERSION"
echo "Release: $ODOO_RELEASE"
if [ -n "$NO_CACHE" ]; then
    echo "Cache: disabled (--no-cache)"
fi
echo "============================================"

docker build \
    $NO_CACHE \
    --build-arg ODOO_SOURCE_URL="$ODOO_SOURCE_URL" \
    --build-arg ODOO_VERSION="$ODOO_VERSION" \
    --build-arg ODOO_RELEASE="$ODOO_RELEASE" \
    --label "odoo.version=$ODOO_VERSION" \
    --label "odoo.release=$ODOO_RELEASE" \
    --label "odoo.source_url=$ODOO_SOURCE_URL" \
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
