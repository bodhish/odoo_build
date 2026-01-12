#!/bin/bash

# Odoo build script
# Builds the odoo image from Dockerfile and pushes it to local registry
#
# Usage:
#   ./odoo.sh <image_name> <image_tag> <registry_host> <registry_port> [dockerfile_path]
#
# Example:
#   ./odoo.sh odoo v1.0.0 localhost 30582

set -e

# Check if all required arguments are provided
if [ $# -lt 4 ]; then
    echo "Error: Missing required arguments"
    echo "Usage: $0 <image_name> <image_tag> <registry_host> <registry_port> [dockerfile_path]"
    exit 1
fi

IMAGE_NAME=$1
IMAGE_TAG=$2
REGISTRY_HOST=$3
REGISTRY_PORT=$4
DOCKERFILE_PATH=${5:-"Dockerfile"}

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Build the Docker image
FULL_IMAGE_NAME="${REGISTRY_HOST}:${REGISTRY_PORT}/${IMAGE_NAME}:${IMAGE_TAG}"
echo "Building Docker image: $FULL_IMAGE_NAME"

# Check if Dockerfile exists
if [ ! -f "$SCRIPT_DIR/$DOCKERFILE_PATH" ]; then
    echo "Error: Dockerfile not found: $SCRIPT_DIR/$DOCKERFILE_PATH"
    exit 1
fi

docker build -f "$SCRIPT_DIR/$DOCKERFILE_PATH" -t "$FULL_IMAGE_NAME" "$SCRIPT_DIR"

# Push the image
echo "Pushing image to registry: $FULL_IMAGE_NAME"
docker push "$FULL_IMAGE_NAME"

echo "Build and push completed successfully!"
echo "Image: $FULL_IMAGE_NAME"