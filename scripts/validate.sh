#!/bin/bash
# scripts/validate.sh

set -euo pipefail

# Load environment variables
if [[ -f ".env" ]]; then
    source .env
else
    echo "❌ .env file not found. Run ./scripts/setup.sh first"
    exit 1
fi

echo "🔍 Multi-Cloud Mirror Validation"
echo "==============================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_tool() {
    local tool="$1"
    if command -v "$tool" >/dev/null 2>&1; then
        echo -e "✓ ${GREEN}$tool${NC} is installed"
        return 0
    else
        echo -e "✗ ${RED}$tool${NC} is missing"
        return 1
    fi
}

validate_aws() {
    echo "🔍 Validating AWS ECR..."

    if ! check_tool "aws"; then
        return 1
    fi

    if aws sts get-caller-identity >/dev/null 2>&1; then
        echo -e "✓ ${GREEN}AWS authentication${NC} working"

        for region in $(echo "${ECR_MIRROR_AWS_REGIONS:-ap-southeast-2}" | tr ',' '\n'); do
            if aws ecr describe-repositories --region "$region" --max-items 1 >/dev/null 2>&1; then
                echo -e "✓ ${GREEN}ECR access${NC} in $region"
            else
                echo -e "✗ ${RED}ECR access failed${NC} in $region"
            fi
        done
    else
        echo -e "✗ ${RED}AWS authentication failed${NC}"
        echo "Run: aws configure"
    fi
}

validate_gcp() {
    echo "🔍 Validating Google GAR..."

    if ! check_tool "gcloud"; then
        return 1
    fi

    if gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -1 >/dev/null 2>&1; then
        echo -e "✓ ${GREEN}GCP authentication${NC} working"

        if [[ -n "${GCP_PROJECT_ID:-}" ]]; then
            gcloud config set project "$GCP_PROJECT_ID" --quiet

            for region in $(echo "${GCR_GCP_REGIONS:-australia-southeast1}" | tr ',' '\n'); do
                if gcloud artifacts locations describe "$region" >/dev/null 2>&1; then
                    echo -e "✓ ${GREEN}GAR access${NC} in $region"
                else
                    echo -e "✗ ${RED}GAR access failed${NC} in $region"
                fi
            done
        else
            echo -e "⚠️  ${YELLOW}GCP_PROJECT_ID not set${NC}"
        fi
    else
        echo -e "✗ ${RED}GCP authentication failed${NC}"
        echo "Run: gcloud auth login"
    fi
}

validate_azure() {
    echo "🔍 Validating Azure ACR..."

    if ! check_tool "az"; then
        return 1
    fi

    if az account show >/dev/null 2>&1; then
        echo -e "✓ ${GREEN}Azure authentication${NC} working"

        if [[ -n "${AZURE_RESOURCE_GROUP:-}" ]]; then
            if az group show --name "$AZURE_RESOURCE_GROUP" >/dev/null 2>&1; then
                echo -e "✓ ${GREEN}Resource group${NC} exists: $AZURE_RESOURCE_GROUP"
            else
                echo -e "⚠️  ${YELLOW}Resource group${NC} not found: $AZURE_RESOURCE_GROUP"
            fi
        else
            echo -e "⚠️  ${YELLOW}AZURE_RESOURCE_GROUP not set${NC}"
        fi
    else
        echo -e "✗ ${RED}Azure authentication failed${NC}"
        echo "Run: az login"
    fi
}

validate_digitalocean() {
    echo "🔍 Validating DigitalOcean..."

    if ! check_tool "doctl"; then
        return 1
    fi

    if [[ -n "${DOCR_TOKEN:-}" ]]; then
        if echo "$DOCR_TOKEN" | crane auth login registry.digitalocean.com -u unused --password-stdin >/dev/null 2>&1; then
            echo -e "✓ ${GREEN}DigitalOcean authentication${NC} working"
        else
            echo -e "✗ ${RED}DigitalOcean authentication failed${NC}"
        fi
    else
        echo -e "⚠️  ${YELLOW}DOCR_TOKEN not set${NC}"
    fi
}

validate_jfrog() {
    echo "🔍 Validating JFrog..."

    if [[ -n "${JFROG_URL:-}" && -n "${JFROG_USER:-}" && -n "${JFROG_TOKEN:-}" ]]; then
        JFROG_HOST=$(echo "$JFROG_URL" | sed -n 's|https\?://\([^/]*\).*|\1|p')

        if crane auth login -u "$JFROG_USER" -p "$JFROG_TOKEN" "$JFROG_HOST" >/dev/null 2>&1; then
            echo -e "✓ ${GREEN}JFrog authentication${NC} working"
        else
            echo -e "✗ ${RED}JFrog authentication failed${NC}"
        fi
    else
        echo -e "⚠️  ${YELLOW}JFrog credentials not set${NC} (JFROG_URL, JFROG_USER, JFROG_TOKEN)"
    fi
}

validate_crane() {
    echo "🔍 Validating crane tool..."

    if check_tool "crane"; then
        CRANE_VERSION=$(crane version 2>/dev/null || echo "unknown")
        echo -e "✓ ${GREEN}Crane version:${NC} $CRANE_VERSION"
    else
        echo -e "✗ ${RED}Crane not found${NC}"
        echo "Install: go install github.com/google/go-containerregistry/cmd/crane@latest"
        return 1
    fi
}

check_config_files() {
    echo "🔍 Validating configuration files..."

    if [[ -f "config/example-list.txt" ]]; then
        echo -e "✓ ${GREEN}Image list file${NC} found"
        TOTAL_IMAGES=$(grep -v '^#\|^$\|^--' config/example-list.txt | wc -l)
        echo -e "  ${TOTAL_IMAGES} images configured"
    else
        echo -e "✗ ${RED}config/example-list.txt${NC} not found"
    fi

    if [[ -f "config/regions.conf" ]]; then
        echo -e "✓ ${GREEN}Regions config${NC} found"
    else
        echo -e "⚠️  ${YELLOW}config/regions.conf${NC} not found"
    fi
}

# Main validation
main() {
    validate_crane
    echo ""
    validate_aws
    echo ""
    validate_gcp
    echo ""
    validate_azure
    echo ""
    validate_digitalocean
    echo ""
    validate_jfrog
    echo ""
    check_config_files

    echo ""
    echo "🎯 Validation Summary"
    echo "===================="
    echo "Review any ✗ or ⚠️  items above before running mirror.sh"
}

main "$@"
