#!/bin/bash
#
# Datalab Inference Container Runner
#
# This script pulls and runs the Datalab inference container
#
# Usage:
#   DATALAB_LICENSE_KEY=your-key SERVICE_ACCOUNT_KEY_FILE=path/to/key.json ./run-datalab-inference-container.sh [OPTIONS]
#
# Required Environment Variables:
#   DATALAB_LICENSE_KEY          Your Datalab license key
#   SERVICE_ACCOUNT_KEY_FILE     Path to Google Cloud service account JSON key file
#
# Optional Environment Variables:
#   CONTAINER_VERSION           Container version tag (default: latest)
#   INFERENCE_PORT              Port to run the inference server on (default: 8000)
#   INFERENCE_HOST              Host interface to bind to (default: localhost, use 0.0.0.0 for external access)
#   DOCKER_EXTRA_ARGS           Additional arguments to pass to docker run
#
# Examples:
#   # Basic usage
#   DATALAB_LICENSE_KEY=ABC123 SERVICE_ACCOUNT_KEY_FILE=./key.json ./run-datalab-inference-container.sh
#
#   # With custom port and version
#   DATALAB_LICENSE_KEY=ABC123 SERVICE_ACCOUNT_KEY_FILE=./key.json INFERENCE_PORT=8001 CONTAINER_VERSION=v1.0.0 ./run-datalab-inference-container.sh
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

# Function to show help
show_help() {
    cat << 'EOF'
Datalab Inference Container Runner

This script pulls and runs the Datalab inference container for customers.

Usage:
    DATALAB_LICENSE_KEY=your-key SERVICE_ACCOUNT_KEY_FILE=path/to/key.json ./run-datalab-inference-container.sh [OPTIONS]

Required Environment Variables:
    DATALAB_LICENSE_KEY          Your Datalab license key
    SERVICE_ACCOUNT_KEY_FILE     Path to Google Cloud service account JSON key file

Optional Environment Variables:
    CONTAINER_VERSION           Container version tag (default: latest)
    INFERENCE_PORT              Port to run the inference server on (default: 8000)
    INFERENCE_HOST              Host interface to bind to (default: 127.0.0.1, use 0.0.0.0 for external access)
    DOCKER_EXTRA_ARGS           Additional arguments to pass to docker run

Examples:
    # Basic usage
    DATALAB_LICENSE_KEY=ABC123 SERVICE_ACCOUNT_KEY_FILE=./key.json ./run-datalab-inference-container.sh

    # With custom port and version
    DATALAB_LICENSE_KEY=ABC123 SERVICE_ACCOUNT_KEY_FILE=./key.json INFERENCE_PORT=8001 CONTAINER_VERSION=v1.0.0 ./run-datalab-inference-container.sh

    # With external access (accessible from outside the VM)
    DATALAB_LICENSE_KEY=ABC123 SERVICE_ACCOUNT_KEY_FILE=./key.json INFERENCE_HOST=0.0.0.0 ./run-datalab-inference-container.sh

    # With custom license server (for testing)
    DATALAB_LICENSE_KEY=ABC123 SERVICE_ACCOUNT_KEY_FILE=./key.json DATALAB_LICENSE_SERVER=https://staging.datalab.to ./run-datalab-inference-container.sh
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information."
            exit 1
            ;;
    esac
done

# Validate required environment variables
if [[ -z "$DATALAB_LICENSE_KEY" ]]; then
    print_error "DATALAB_LICENSE_KEY environment variable is required"
    echo "Example: DATALAB_LICENSE_KEY=your-key SERVICE_ACCOUNT_KEY_FILE=./key.json $0"
    exit 1
fi

if [[ -z "$SERVICE_ACCOUNT_KEY_FILE" ]]; then
    print_error "SERVICE_ACCOUNT_KEY_FILE environment variable is required"
    echo "Example: DATALAB_LICENSE_KEY=your-key SERVICE_ACCOUNT_KEY_FILE=./key.json $0"
    exit 1
fi

# Validate service account key file exists
if [[ ! -f "$SERVICE_ACCOUNT_KEY_FILE" ]]; then
    print_error "Service account key file not found: $SERVICE_ACCOUNT_KEY_FILE"
    exit 1
fi

# Set default values
CONTAINER_VERSION="${CONTAINER_VERSION:-latest}"
INFERENCE_PORT="${INFERENCE_PORT:-8000}"
INFERENCE_HOST="${INFERENCE_HOST:-127.0.0.1}"
DOCKER_EXTRA_ARGS="${DOCKER_EXTRA_ARGS:-}"

# Container configuration
REGISTRY_URL="us-docker.pkg.dev"
PROJECT_ID="datalab-customer-images"
REPOSITORY_NAME="datalab-inference-container"
IMAGE_NAME="datalab-inference"
FULL_IMAGE_PATH="${REGISTRY_URL}/${PROJECT_ID}/${REPOSITORY_NAME}/${IMAGE_NAME}:${CONTAINER_VERSION}"

# Display configuration
print_info "=== Datalab Inference Container Configuration ==="
echo "Container Version: $CONTAINER_VERSION"
echo "Inference Port: $INFERENCE_PORT"
echo "Service Account Key: $SERVICE_ACCOUNT_KEY_FILE"
echo "Container Image: $FULL_IMAGE_PATH"
echo ""

# Check if required commands are available
print_info "Checking prerequisites..."

if ! command -v docker >/dev/null 2>&1; then
    print_error "Docker is not installed or not in PATH"
    exit 1
fi

if ! command -v gcloud >/dev/null 2>&1; then
    print_error "Google Cloud SDK is not installed or not in PATH"
    print_error "Please install gcloud: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

print_success "Prerequisites check passed"

# Authenticate with Google Cloud using service account
print_info "Authenticating with Google Cloud..."

if ! gcloud auth activate-service-account --key-file="$SERVICE_ACCOUNT_KEY_FILE" --quiet; then
    print_error "Failed to authenticate with Google Cloud using service account key"
    exit 1
fi

print_success "Authenticated with Google Cloud"

# Configure Docker to use gcloud credentials
print_info "Configuring Docker authentication..."

if ! gcloud auth configure-docker "$REGISTRY_URL" --quiet; then
    print_error "Failed to configure Docker authentication"
    exit 1
fi

print_success "Docker authentication configured"

# Pull the container image
print_info "Pulling container image: $FULL_IMAGE_PATH"

if ! docker pull "$FULL_IMAGE_PATH"; then
    print_error "Failed to pull container image"
    print_error "Please check:"
    print_error "  1. Your service account has access to the repository"
    print_error "  2. The container version '$CONTAINER_VERSION' exists"
    print_error "  3. Your internet connection is working"
    exit 1
fi

print_success "Container image pulled successfully"

# Check for GPU support
print_info "Checking GPU support..."

GPU_ARGS=""
if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then
    GPU_COUNT=$(nvidia-smi -L | wc -l)
    print_success "Found $GPU_COUNT GPU(s), enabling GPU support"
    GPU_ARGS="--gpus all"
else
    print_warning "No GPUs detected, running in CPU-only mode (performance will be limited)"
fi

# Prepare Docker run command
# Build Docker command with optional DATALAB_LICENSE_SERVER
DOCKER_ENV_VARS="-e INFERENCE_PORT=$INFERENCE_PORT -e DATALAB_LICENSE_KEY=$DATALAB_LICENSE_KEY"
if [[ -n "$DATALAB_LICENSE_SERVER" ]]; then
    DOCKER_ENV_VARS="$DOCKER_ENV_VARS -e DATALAB_LICENSE_SERVER=$DATALAB_LICENSE_SERVER"
fi

DOCKER_CMD="docker run --rm -it \
    $GPU_ARGS \
    -p $INFERENCE_HOST:$INFERENCE_PORT:$INFERENCE_PORT \
    $DOCKER_ENV_VARS \
    $DOCKER_EXTRA_ARGS \
    $FULL_IMAGE_PATH"

print_info "=== Starting Datalab Inference Container ==="
if [[ "$INFERENCE_HOST" == "0.0.0.0" ]]; then
    print_info "Container will be available at: http://0.0.0.0:$INFERENCE_PORT (accessible externally)"
else
    print_info "Container will be available at: http://$INFERENCE_HOST:$INFERENCE_PORT"
fi
print_info "Press Ctrl+C to stop the container"
echo ""
print_info "Docker command:"
echo "$DOCKER_CMD"
echo ""

# Run the container
exec $DOCKER_CMD
