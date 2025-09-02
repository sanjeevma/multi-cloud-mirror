# Troubleshooting Guide

## Common Issues and Solutions

### Authentication Problems

#### AWS ECR Authentication Failed
```
Error: Unable to locate credentials
```

**Solutions:**
```bash
# Check AWS credentials
aws sts get-caller-identity

# Configure AWS CLI
aws configure

# Or set environment variables
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
export AWS_DEFAULT_REGION="us-east-1"

# For EC2 instances, ensure IAM role has ECR permissions
```

**Required ECR Permissions:**
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecr:GetAuthorizationToken",
                "ecr:CreateRepository",
                "ecr:DescribeRepositories",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ecr:PutImage",
                "ecr:InitiateLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:CompleteLayerUpload"
            ],
            "Resource": "*"
        }
    ]
}
```

#### Google GAR Authentication Failed
```
Error: (gcloud.auth.application-default.login) There was a problem with web authentication
```

**Solutions:**
```bash
# Re-authenticate
gcloud auth login
gcloud auth application-default login

# Set project
gcloud config set project YOUR_PROJECT_ID

# For service accounts
gcloud auth activate-service-account --key-file=path/to/key.json

# Check current auth
gcloud auth list
```

#### Azure ACR Authentication Failed
```
Error: Please run 'az login' to setup account
```

**Solutions:**
```bash
# Interactive login
az login

# Service principal login
az login --service-principal \
  -u $AZURE_CLIENT_ID \
  -p $AZURE_CLIENT_SECRET \
  --tenant $AZURE_TENANT_ID

# Check subscription
az account show

# Login to specific ACR
az acr login --name your-registry-name
```

#### JFrog Authentication Failed
```
Error: crane: GET https://yourcompany.jfrog.io/...: UNAUTHORIZED
```

**Solutions:**
```bash
# Check JFrog credentials
curl -u "$JFROG_USER:$JFROG_TOKEN" "$JFROG_URL/artifactory/api/system/ping"

# Test with curl
curl -u username:token https://yourcompany.jfrog.io/artifactory/api/repositories

# Generate new API token in JFrog UI: User Profile > Generate API Key
```

#### DigitalOcean Authentication Failed
```
Error: authentication required
```

**Solutions:**
```bash
# Check DOCR token
doctl auth init --access-token $DOCR_TOKEN

# Verify token works
doctl registry get

# Generate new token: DigitalOcean Control Panel > API > Personal Access Tokens
```

### Image Transfer Issues

#### Network Timeouts
```
Error: context deadline exceeded
```

**Solutions:**
```bash
# Reduce parallel jobs
./mirror.sh -j 1

# Increase retry attempts
./mirror.sh -r 5

# Check network connectivity
crane ls docker.io/library/nginx

# Use debug mode to see detailed errors
./mirror.sh -d
```

#### Registry Quota Exceeded
```
Error: DENIED: requested access to the resource is denied
```

**Solutions:**
```bash
# Check registry storage limits
aws ecr describe-registry
gcloud artifacts repositories describe REPO --location=REGION
az acr show-usage --name REGISTRY

# Clean up old images
aws ecr list-images --repository-name REPO --filter tagStatus=UNTAGGED
gcloud artifacts docker images delete IMAGE_URL
az acr repository delete --name REGISTRY --repository REPO
```

#### Repository Creation Failed
```
Error: Repository already exists with different configuration
```

**Solutions:**
```bash
# Check existing repository settings
aws ecr describe-repositories --repository-name REPO
gcloud artifacts repositories describe REPO --location=REGION
az acr repository show --name REGISTRY --repository REPO

# Delete and recreate if necessary
aws ecr delete-repository --repository-name REPO --force
gcloud artifacts repositories delete REPO --location=REGION
az acr repository delete --name REGISTRY --repository REPO
```

### Platform-Specific Issues

#### AWS ECR Issues

**Repository Limit Exceeded:**
```bash
# Check current repositories
aws ecr describe-repositories --query 'repositories[].repositoryName'

# AWS ECR limits: 10,000 repositories per region by default
# Request limit increase via AWS Support
```

**Cross-region Replication:**
```bash
# Enable ECR replication
aws ecr put-replication-configuration --replication-configuration file://replication.json
```

#### Google GAR Issues

**Service Account Permissions:**
```bash
# Required roles for GAR
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:SERVICE_ACCOUNT" \
  --role="roles/artifactregistry.admin"
```

**Location/Region Errors:**
```bash
# List available GAR locations
gcloud artifacts locations list

# Ensure region format is correct (e.g., us-central1, not us-central1-a)
```

#### Azure ACR Issues

**Resource Group Missing:**
```bash
# Create resource group
az group create --name container-registries-rg --location eastus

# Check existing resource groups
az group list --output table
```

**ACR Name Conflicts:**
```bash
# ACR names must be globally unique
# Check availability
az acr check-name --name your-registry-name

# Use org prefix: orgname-region-acr
```

#### JFrog Issues

**Repository Type Mismatch:**
```bash
# Ensure repository is Docker type, not Maven/npm
# Check via JFrog UI: Administration > Repositories > Local

# Repository URL format:
# https://yourcompany.jfrog.io/artifactory/docker-local
```

**SSL Certificate Issues:**
```bash
# Skip SSL verification (not recommended for production)
export CRANE_INSECURE=true

# Or add custom CA certificate
crane copy --platform linux/amd64 SOURCE TARGET --insecure
```

#### DigitalOcean Issues

**Registry Name Format:**
```bash
# DOCR registry names must be lowercase and 3-63 characters
# Can contain letters, numbers, and hyphens
# Cannot start or end with hyphen

# Check existing registries
doctl registry get
```

### Performance Issues

#### Slow Transfer Speeds
```bash
# Check image sizes
crane manifest docker.io/nginx:latest | jq '.config.size'

# Use smaller base images
# alpine instead of ubuntu
# distroless images
# multi-stage builds

# Transfer during off-peak hours
# Use regions closer to source registry
```

#### Memory Issues
```bash
# Monitor system resources
top
htop
docker system df

# Reduce parallel jobs
./mirror.sh -j 1

# Clean up local Docker cache
docker system prune -f
```

### Configuration Issues

#### Invalid Image List Format
```
Error: Unknown target keyword 'XYZ'
```

**Solution:**
```bash
# Valid destinations only: ECR,GAR,ACR,JFROG,DOCR
# Check config/example-list.txt format:
ECR,GAR docker.io/nginx:latest
ACR,JFROG docker.io/redis:alpine

# Lines starting with # are comments
# Empty lines are ignored
```

#### Missing Configuration Files
```
Error: config/example-list.txt not found
```

**Solution:**
```bash
# Ensure file structure is correct
tree multi-cloud-mirror/

# Create missing files
touch config/example-list.txt
touch config/regions.conf
```

### Debugging Commands

#### Test Individual Registry Connections
```bash
# AWS ECR
aws ecr get-login-password --region us-east-1 | crane auth login --username AWS --password-stdin AWS_ACCOUNT.dkr.ecr.us-east-1.amazonaws.com

# Google GAR
gcloud auth configure-docker us-central1-docker.pkg.dev
crane ls us-central1-docker.pkg.dev/PROJECT/REPO

# Azure ACR
az acr login --name your-registry
crane ls your-registry.azurecr.io

# JFrog
crane auth login -u USERNAME -p TOKEN yourcompany.jfrog.io
crane ls yourcompany.jfrog.io/artifactory/docker-local

# DigitalOcean
echo $DOCR_TOKEN | crane auth login registry.digitalocean.com -u unused --password-stdin
crane ls registry.digitalocean.com/your-registry
```

#### Test Image Copy
```bash
# Test single image copy
crane copy docker.io/hello-world:latest your-registry.com/hello-world:test

# Verify image was copied
crane manifest your-registry.com/hello-world:test

# Test with different platform
crane copy --platform linux/arm64 SOURCE TARGET
```

#### Check Registry Capabilities
```bash
# Check supported platforms
crane manifest docker.io/nginx:latest | jq '.manifests[].platform'

# Check image layers
crane config docker.io/nginx:latest | jq '.config'

# List repository contents
crane ls your-registry.com/nginx
```

### Environment-Specific Issues

#### Running in CI/CD
```bash
# Use service accounts instead of interactive auth
# Set explicit timeouts
export CRANE_TIMEOUT=300s

# Use non-interactive flags
gcloud config set disable_prompts true
az configure --defaults --only-show-errors
```

#### Running in Docker
```bash
# Mount credentials as volumes
docker run -v ~/.aws:/root/.aws:ro \
  -v ~/.config/gcloud:/root/.config/gcloud:ro \
  your-mirror-image

# Or use environment variables
docker run -e AWS_ACCESS_KEY_ID \
  -e AWS_SECRET_ACCESS_KEY \
  your-mirror-image
```

#### Running on Different OS

**macOS Issues:**
```bash
# Install dependencies via Homebrew
brew install crane awscli google-cloud-sdk azure-cli doctl

# GNU sed vs BSD sed differences
# Use gsed if available: brew install gnu-sed
```

**Windows WSL2:**
```bash
# Install Ubuntu/Debian packages
sudo apt update
sudo apt install curl wget unzip

# Ensure Docker Desktop integration is enabled
# Use WSL2 file system, not Windows drives
```

### Getting Help

#### Enable Comprehensive Logging
```bash
# Full debug mode
DEBUG=1 ./mirror.sh -d -f single-image.txt

# Log to file
./mirror.sh -d 2>&1 | tee mirror.log

# Check individual registry functions
DEBUG=1 source lib/ecr.sh && push_to_ecr docker.io/nginx:alpine
```

#### Check Tool Versions
```bash
# Verify tool versions
crane version
aws --version
gcloud version
az version
doctl version

# Update if needed
```

#### Contact Support
- **GitHub Issues**: For bugs and feature requests
- **Discussions**: For usage questions and community support
- **Registry Support**: Contact respective cloud providers for registry-specific issues

### Performance Optimization

#### Optimal Settings by Use Case

**Small Images (<100MB):**
```bash
./mirror.sh -j 10 -r 2
```

**Large Images (>1GB):**
```bash
./mirror.sh -j 2 -r 5
```

**High Latency Networks:**
```bash
./mirror.sh -j 1 -r 10
```

**Enterprise/Production:**
```bash
./mirror.sh -j 5 -r 3 -d > mirror.log 2>&1
```
