#!/bin/bash
# mirror.sh - Multi-cloud container image mirroring

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration
if [[ -f "$SCRIPT_DIR/.env" ]]; then
   source "$SCRIPT_DIR/.env"
elif [[ -f "$SCRIPT_DIR/config/regions.conf" ]]; then
   source "$SCRIPT_DIR/config/regions.conf"
fi

# Load library functions
source "$SCRIPT_DIR/lib/ecr.sh"
source "$SCRIPT_DIR/lib/gar.sh"
source "$SCRIPT_DIR/lib/acr.sh"
source "$SCRIPT_DIR/lib/jfrog.sh"
source "$SCRIPT_DIR/lib/docr.sh"

# Default values
MAX_PARALLEL_JOBS="${MAX_PARALLEL_JOBS:-3}"
MAX_RETRIES="${MAX_RETRIES:-3}"
RETRY_DELAY="${RETRY_DELAY:-5}"
TARGET_PLATFORM="${TARGET_PLATFORM:-linux/amd64}"
DEBUG="${DEBUG:-0}"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() {
   echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
   echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
   echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
   echo -e "${RED}[ERROR]${NC} $1"
}

debug_log() {
   [[ "$DEBUG" == "1" ]] && echo -e "${YELLOW}[DEBUG]${NC} $1"
}

# Show usage
usage() {
   cat << EOF
Usage: $0 [OPTIONS]

Multi-cloud container image mirroring tool

OPTIONS:
   -f, --file FILE          Image list file (default: config/example-list.txt)
   -j, --jobs N            Max parallel jobs (default: $MAX_PARALLEL_JOBS)
   -r, --retries N         Max retries per image (default: $MAX_RETRIES)
   -p, --platform PLATFORM Target platform (default: $TARGET_PLATFORM)
   -d, --debug             Enable debug output
   -v, --validate          Run validation only
   -h, --help              Show this help

EXAMPLES:
   $0                                          # Mirror using default config
   $0 -f custom-list.txt -j 5                 # Custom file, 5 parallel jobs
   $0 --validate                              # Validate setup only
   $0 -d -r 5                                 # Debug mode, 5 retries

EOF
}

# Parse command line arguments
parse_args() {
   IMAGE_LIST_FILE="$SCRIPT_DIR/config/example-list.txt"
   VALIDATE_ONLY=0

   while [[ $# -gt 0 ]]; do
       case $1 in
           -f|--file)
               IMAGE_LIST_FILE="$2"
               shift 2
               ;;
           -j|--jobs)
               MAX_PARALLEL_JOBS="$2"
               shift 2
               ;;
           -r|--retries)
               MAX_RETRIES="$2"
               shift 2
               ;;
           -p|--platform)
               TARGET_PLATFORM="$2"
               shift 2
               ;;
           -d|--debug)
               DEBUG=1
               shift
               ;;
           -v|--validate)
               VALIDATE_ONLY=1
               shift
               ;;
           -h|--help)
               usage
               exit 0
               ;;
           *)
               log_error "Unknown option: $1"
               usage
               exit 1
               ;;
       esac
   done
}

# Validate prerequisites
validate_setup() {
   log_info "Validating setup..."

   if ! command -v crane >/dev/null 2>&1; then
       log_error "crane tool not found. Run ./scripts/setup.sh"
       exit 1
   fi

   if [[ ! -f "$IMAGE_LIST_FILE" ]]; then
       log_error "Image list file not found: $IMAGE_LIST_FILE"
       exit 1
   fi

   log_success "Basic validation passed"
}

# Authenticate to all registries
authenticate_all() {
   log_info "Authenticating to registries..."

   # AWS ECR
   if [[ "${ECR_MIRROR_AWS_REGIONS:-}" ]]; then
       authenticate_ecr || log_warning "ECR authentication failed"
   fi

   # Google GAR
   if [[ "${GCR_GCP_REGIONS:-}" ]]; then
       authenticate_gar || log_warning "GAR authentication failed"
   fi

   # Azure ACR
   if [[ "${ACR_AZURE_REGIONS:-}" ]]; then
       authenticate_acr || log_warning "ACR authentication failed"
   fi

   # JFrog
   if [[ "${JFROG_URL:-}" ]]; then
       authenticate_jfrog || log_warning "JFrog authentication failed"
   fi

   # DigitalOcean
   if [[ "${DOCR_TOKEN:-}" ]]; then
       authenticate_docr || log_warning "DigitalOcean authentication failed"
   fi

   log_success "Authentication complete"
}

# Mirror single image with retry logic
mirror_image_with_retry() {
   local dest="$1"
   local source="$2"
   local attempt=1

   while [[ $attempt -le $MAX_RETRIES ]]; do
       debug_log "Attempt $attempt/$MAX_RETRIES for $source"

       IFS=',' read -ra TARGETS <<< "$dest"
       local success=true

       for target in "${TARGETS[@]}"; do
           case "$target" in
               ECR)
                   if ! push_to_ecr "$source"; then
                       success=false
                   fi
                   ;;
               GAR)
                   if ! push_to_gar "$source"; then
                       success=false
                   fi
                   ;;
               ACR)
                   if ! push_to_acr "$source"; then
                       success=false
                   fi
                   ;;
               JFROG)
                   if ! push_to_jfrog "$source"; then
                       success=false
                   fi
                   ;;
               DOCR)
                   if ! push_to_docr "$source"; then
                       success=false
                   fi
                   ;;
               *)
                   log_error "Unknown target: $target"
                   success=false
                   ;;
           esac
       done

       if $success; then
           log_success "Mirrored: $source"
           return 0
       else
           log_warning "Attempt $attempt failed for $source, retrying in ${RETRY_DELAY}s..."
           sleep "$RETRY_DELAY"
           ((attempt++))
       fi
   done

   log_error "Failed to mirror after $MAX_RETRIES attempts: $source"
   return 1
}

# Process image list
process_images() {
   log_info "Processing image list: $IMAGE_LIST_FILE"

   local total_images=0
   local successful_images=0
   local failed_images=0

   # Count total images
   total_images=$(grep -v '^#\|^$\|^--' "$IMAGE_LIST_FILE" | wc -l)
   log_info "Total images to mirror: $total_images"

   # Process each line
   while IFS= read -r line; do
       DEST=$(echo "$line" | awk '{print $1}')
       SOURCE=$(echo "$line" | awk '{print $2}')

       # Skip comments and empty lines
       [[ -z "$SOURCE" || "$SOURCE" =~ ^# || "$SOURCE" =~ ^-+ ]] && continue

       # Validate destination
       if [[ "$DEST" != *"ECR"* && "$DEST" != *"GAR"* && "$DEST" != *"ACR"* && "$DEST" != *"JFROG"* && "$DEST" != *"DOCR"* ]]; then
           log_warning "Invalid destination '$DEST' for $SOURCE, skipping..."
           continue
       fi

       log_info "Processing: $SOURCE -> $DEST"

       if mirror_image_with_retry "$DEST" "$SOURCE"; then
           ((successful_images++))
       else
           ((failed_images++))
       fi

   done < "$IMAGE_LIST_FILE"

   # Summary
   echo ""
   log_info "Mirroring Summary"
   log_info "================="
   log_success "Successful: $successful_images"
   if [[ $failed_images -gt 0 ]]; then
       log_error "Failed: $failed_images"
   else
       log_success "Failed: $failed_images"
   fi
   log_info "Total: $total_images"
}

# Signal handlers
cleanup() {
   log_info "Cleaning up..."
   # Kill any background jobs
   jobs -p | xargs -r kill 2>/dev/null || true
   exit 130
}

trap cleanup INT TERM

# Main function
main() {
   echo "🚀 Multi-Cloud Container Mirror"
   echo "==============================="

   parse_args "$@"

   if [[ $VALIDATE_ONLY -eq 1 ]]; then
       exec "$SCRIPT_DIR/scripts/validate.sh"
   fi

   validate_setup
   authenticate_all
   process_images

   log_success "Multi-cloud mirroring complete!"
}

# Run main function
main "$@"
