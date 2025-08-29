#!/bin/bash
#
# Datalab Inference Container Image Lister
#
# This script lists all available image tags in the Datalab inference container repository
#
# Usage:
#   SERVICE_ACCOUNT_KEY_FILE=path/to/key.json ./list-images.sh [OPTIONS]
#
# Required Environment Variables:
#   SERVICE_ACCOUNT_KEY_FILE     Path to Google Cloud service account JSON key file
#
# Optional Environment Variables:
#   FORMAT                       Output format: table, json, or tags-only (default: table)
#
# Examples:
#   # Basic usage - show table format
#   SERVICE_ACCOUNT_KEY_FILE=./key.json ./list-images.sh
#
#   # Show only tags
#   SERVICE_ACCOUNT_KEY_FILE=./key.json FORMAT=tags-only ./list-images.sh
#
#   # Show JSON output
#   SERVICE_ACCOUNT_KEY_FILE=./key.json FORMAT=json ./list-images.sh
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
Datalab Inference Container Image Lister

This script lists all available image tags in the Datalab inference container repository.

Usage:
    SERVICE_ACCOUNT_KEY_FILE=path/to/key.json ./list-images.sh [OPTIONS]

Required Environment Variables:
    SERVICE_ACCOUNT_KEY_FILE     Path to Google Cloud service account JSON key file

Optional Environment Variables:
    FORMAT                       Output format: table, json, or tags-only (default: table)

Examples:
    # Basic usage - show table format
    SERVICE_ACCOUNT_KEY_FILE=./key.json ./list-images.sh

    # Show only tags
    SERVICE_ACCOUNT_KEY_FILE=./key.json FORMAT=tags-only ./list-images.sh

    # Show JSON output
    SERVICE_ACCOUNT_KEY_FILE=./key.json FORMAT=json ./list-images.sh
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
if [[ -z "$SERVICE_ACCOUNT_KEY_FILE" ]]; then
    print_error "SERVICE_ACCOUNT_KEY_FILE environment variable is required"
    echo "Example: SERVICE_ACCOUNT_KEY_FILE=./key.json $0"
    exit 1
fi

# Validate service account key file exists
if [[ ! -f "$SERVICE_ACCOUNT_KEY_FILE" ]]; then
    print_error "Service account key file not found: $SERVICE_ACCOUNT_KEY_FILE"
    exit 1
fi

# Set default values
FORMAT="${FORMAT:-table}"

# Validate format
case "$FORMAT" in
    table|json|tags-only)
        ;;
    *)
        print_error "Invalid format: $FORMAT. Valid options: table, json, tags-only"
        exit 1
        ;;
esac

# Container repository configuration
REGISTRY_URL="us-docker.pkg.dev"
PROJECT_ID="datalab-customer-images"
REPOSITORY_NAME="datalab-inference-container"
IMAGE_NAME="datalab-inference"
FULL_REPOSITORY_PATH="${REGISTRY_URL}/${PROJECT_ID}/${REPOSITORY_NAME}/${IMAGE_NAME}"

# Check if required commands are available
if ! command -v gcloud >/dev/null 2>&1; then
    print_error "Google Cloud SDK is not installed or not in PATH"
    print_error "Please install gcloud: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Authenticate with Google Cloud using service account
print_info "Authenticating and listing tags..."

if ! gcloud auth activate-service-account --key-file="$SERVICE_ACCOUNT_KEY_FILE" --quiet >/dev/null 2>&1; then
    print_error "Failed to authenticate with Google Cloud using service account key"
    exit 1
fi

# Configure Docker to use gcloud credentials (needed for artifact registry access)
if ! gcloud auth configure-docker "$REGISTRY_URL" --quiet >/dev/null 2>&1; then
    print_error "Failed to configure Docker authentication"
    exit 1
fi

case "$FORMAT" in
    table)
        echo ""
        if ! gcloud artifacts docker tags list "$FULL_REPOSITORY_PATH" --format="table(tag.basename(),version.basename():label=DIGEST)"; then
            print_error "Failed to list image tags"
            exit 1
        fi
        ;;
    json)
        echo ""
        if ! gcloud artifacts docker tags list "$FULL_REPOSITORY_PATH" --format="json"; then
            print_error "Failed to list image tags"
            exit 1
        fi
        ;;
    tags-only)
        echo ""
        if ! gcloud artifacts docker tags list "$FULL_REPOSITORY_PATH" --format="value(tag.basename())"; then
            print_error "Failed to list image tags"
            exit 1
        fi
        ;;
esac
