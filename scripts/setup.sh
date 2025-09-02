#!/bin/bash
# scripts/setup.sh

set -euo pipefail

echo "🚀 Multi-Cloud Mirror Setup"
echo "=========================="

# Check if running as root
check_permissions() {
   if [[ $EUID -eq 0 ]]; then
       echo "⚠️  Warning: Running as root. Consider using a non-root user."
   fi
}

# Install required tools
install_dependencies() {
   echo "📦 Installing dependencies..."

   # Detect OS
   if [[ "$OSTYPE" == "linux-gnu"* ]]; then
       # Linux
       if command -v apt-get >/dev/null 2>&1; then
           sudo apt-get update
           sudo apt-get install -y curl wget unzip
       elif command -v yum >/dev/null 2>&1; then
           sudo yum install -y curl wget unzip
       fi
   elif [[ "$OSTYPE" == "darwin"* ]]; then
       # macOS
       if ! command -v brew >/dev/null 2>&1; then
           echo "Installing Homebrew..."
           /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
       fi
   fi

   # Install crane
   if ! command -v crane >/dev/null 2>&1; then
       echo "Installing crane..."
       VERSION=$(curl -s https://api.github.com/repos/google/go-containerregistry/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
       OS=$(uname -s | tr '[:upper:]' '[:lower:]')
       ARCH=$(uname -m | sed 's/x86_64/amd64/')

       curl -sL "https://github.com/google/go-containerregistry/releases/download/${VERSION}/go-containerregistry_${OS}_${ARCH}.tar.gz" | tar xz crane
       sudo mv crane /usr/local/bin/
       echo "✓ Crane installed"
   else
       echo "✓ Crane already installed"
   fi
}

# Setup cloud CLIs
setup_aws_cli() {
   if ! command -v aws >/dev/null 2>&1; then
       echo "Installing AWS CLI..."
       curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
       unzip awscliv2.zip
       sudo ./aws/install
       rm -rf aws awscliv2.zip
       echo "✓ AWS CLI installed"
   else
       echo "✓ AWS CLI already installed"
   fi
}

setup_gcloud_cli() {
   if ! command -v gcloud >/dev/null 2>&1; then
       echo "Installing Google Cloud CLI..."
       curl https://sdk.cloud.google.com | bash
       exec -l $SHELL
       echo "✓ Google Cloud CLI installed"
   else
       echo "✓ Google Cloud CLI already installed"
   fi
}

setup_azure_cli() {
   if ! command -v az >/dev/null 2>&1; then
       echo "Installing Azure CLI..."
       curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
       echo "✓ Azure CLI installed"
   else
       echo "✓ Azure CLI already installed"
   fi
}

setup_doctl() {
   if ! command -v doctl >/dev/null 2>&1; then
       echo "Installing DigitalOcean CLI..."
       VERSION=$(curl -s https://api.github.com/repos/digitalocean/doctl/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
       OS=$(uname -s | tr '[:upper:]' '[:lower:]')
       ARCH=$(uname -m | sed 's/x86_64/amd64/')

       curl -sL "https://github.com/digitalocean/doctl/releases/download/${VERSION}/doctl-${VERSION#v}-${OS}-${ARCH}.tar.gz" | tar xz
       sudo mv doctl /usr/local/bin/
       echo "✓ DigitalOcean CLI installed"
   else
       echo "✓ DigitalOcean CLI already installed"
   fi
}

# Create configuration files
setup_config() {
   echo "📝 Setting up configuration..."

   if [[ ! -f ".env" ]]; then
       cp .env.example .env
       echo "✓ Created .env file from template"
       echo "⚠️  Please edit .env with your actual credentials"
   else
       echo "✓ .env file already exists"
   fi
}

# Main setup
main() {
   check_permissions
   install_dependencies
   setup_aws_cli
   setup_gcloud_cli
   setup_azure_cli
   setup_doctl
   setup_config

   echo ""
   echo "✅ Setup complete!"
   echo "Next steps:"
   echo "1. Edit .env with your credentials"
   echo "2. Run ./scripts/validate.sh to test connections"
   echo "3. Update config/example-list.txt with your images"
   echo "4. Run ./mirror.sh to start mirroring"
}

main "$@"
