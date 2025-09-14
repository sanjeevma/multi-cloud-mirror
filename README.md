# Multi-Cloud Mirror

Multi-cloud container image mirroring tool in bash that synchronizes Docker images across AWS ECR, Google Artifact Registry (GAR), Azure Container Registry (ACR), JFrog Artifactory, and DigitalOcean Container Registry (DOCR).
Its a all in one solution

## Features

- 🌐 **Multi-cloud support**: AWS, Google Cloud, Azure, JFrog, DigitalOcean
- 🔄 **Bulk mirroring** from configuration files
- 🌍 **Multi-region deployment** support
- 🤖 **Automated repository creation**
- 🔐 **Platform-specific authentication**
- ⚡ **Parallel processing** with configurable concurrency
- 🔁 **Retry logic** with exponential backoff
- 📊 **Detailed logging** and progress tracking

## Quick Start

```bash
# 1. Clone and setup
git clone https://github.com/sanjeevma/multi-cloud-mirror.git
cd multi-cloud-mirror
./scripts/setup.sh

# 2. Configure credentials
cp .env.example .env
# Edit .env with your credentials

# 3. Validate setup
./scripts/validate.sh

# 4. Run mirroring
./mirror.sh
```

## File Structure

```
multi-cloud-mirror/
├── README.md                 # This file
├── mirror.sh                 # Main orchestration script
├── lib/                      # Registry-specific functions
│   ├── ecr.sh               # AWS ECR functions
│   ├── gar.sh               # Google GAR functions
│   ├── acr.sh               # Azure ACR functions
│   ├── jfrog.sh             # JFrog functions
│   └── docr.sh              # DigitalOcean functions
├── config/                   # Configuration files
│   ├── example-list.txt     # Image list template
│   └── regions.conf         # Regional configuration
├── scripts/                  # Utility scripts
│   ├── setup.sh             # Environment setup
│   └── validate.sh          # Pre-flight validation
├── docs/                     # Documentation
│   ├── USAGE.md             # Detailed usage guide
│   └── TROUBLESHOOTING.md   # Common issues and solutions
└── .env.example             # Environment variables template
```

## Prerequisites

- **Required Tools**: `crane`, `aws`, `gcloud`, `az`, `doctl`
- **Operating System**: Linux, macOS, WSL2
- **Permissions**: Registry access for target cloud providers

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
# AWS ECR
ECR_MIRROR_AWS_REGIONS="us-east-1,us-west-2,eu-west-1"

# Google GAR
GCP_PROJECT_ID="your-project-id"
GCR_GCP_REGIONS="us-central1,europe-west1"

# Azure ACR
AZURE_RESOURCE_GROUP="container-registries-rg"
ACR_AZURE_REGIONS="eastus,westus2"

# JFrog Artifactory
JFROG_URL="https://yourcompany.jfrog.io"
JFROG_USER="username"
JFROG_TOKEN="api-token"

# DigitalOcean
DOCR_TOKEN="your-do-token"
DOCR_REGISTRY_NAME="your-registry"
```

### Image List Format

Edit `config/example-list.txt`:

```
# Format: DESTINATIONS SOURCE_IMAGE
# Destinations: ECR,GAR,ACR,JFROG,DOCR (comma-separated)

ECR,GAR,ACR docker.io/nginx:1.25-alpine
ECR,GAR,ACR docker.io/redis:7.2-alpine
JFROG,ECR docker.io/postgres:15-alpine
DOCR,GAR docker.io/node:18-alpine
ECR,GAR,ACR,JFROG,DOCR docker.io/busybox:latest
```

## Usage

### Basic Usage

```bash
# Mirror all images using default configuration
./mirror.sh

# Use custom image list
./mirror.sh -f my-images.txt

# Run with 5 parallel jobs
./mirror.sh -j 5

# Enable debug mode
./mirror.sh -d
```

### Advanced Usage

```bash
# Validate setup only
./mirror.sh --validate

# Custom platform and retries
./mirror.sh -p linux/arm64 -r 5

# Full example
./mirror.sh -f prod-images.txt -j 10 -r 3 -d
```

### Command Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `-f, --file` | Image list file | `config/example-list.txt` |
| `-j, --jobs` | Max parallel jobs | `3` |
| `-r, --retries` | Max retries per image | `3` |
| `-p, --platform` | Target platform | `linux/amd64` |
| `-d, --debug` | Enable debug output | `false` |
| `-v, --validate` | Run validation only | `false` |
| `-h, --help` | Show help message | - |

## Authentication

### AWS ECR
```bash
aws configure
# OR set environment variables:
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
```

### Google GAR
```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
```

### Azure ACR
```bash
az login
# OR use service principal:
az login --service-principal -u $AZURE_CLIENT_ID -p $AZURE_CLIENT_SECRET --tenant $AZURE_TENANT_ID
```

### JFrog Artifactory
```bash
export JFROG_USER="your-username"
export JFROG_TOKEN="your-api-token"
```

### DigitalOcean
```bash
export DOCR_TOKEN="your-digitalocean-token"
```

## Registry Support

| Registry | Provider | Features |
|----------|----------|----------|
| **ECR** | AWS | Auto-create repos, vulnerability scanning |
| **GAR** | Google Cloud | Multi-format artifacts, regional deployment |
| **ACR** | Azure | Geo-replication, content trust |
| **JFrog** | Artifactory | Enterprise features, metadata |
| **DOCR** | DigitalOcean | Simple setup, cost-effective |

## Examples

### Mirror Kubernetes Images
```bash
# config/k8s-images.txt
ECR,GAR,ACR k8s.gcr.io/pause:3.9
ECR,GAR,ACR registry.k8s.io/coredns/coredns:v1.10.1
ECR,GAR,ACR registry.k8s.io/etcd:3.5.9-0

./mirror.sh -f config/k8s-images.txt
```

### Development Workflow
```bash
# 1. Validate configuration
./scripts/validate.sh

# 2. Test with single image
echo "ECR docker.io/hello-world:latest" > test.txt
./mirror.sh -f test.txt -d

# 3. Run full mirror
./mirror.sh -j 5
```

## Troubleshooting

### Common Issues

**Authentication Failures**
```bash
# Check credentials
./scripts/validate.sh

# Re-authenticate
aws configure
gcloud auth login
az login
```

**Network Timeouts**
```bash
# Reduce parallel jobs
./mirror.sh -j 1 -r 5

# Check crane connectivity
crane ls docker.io/library/nginx
```

**Registry Quota Issues**
- Check registry storage limits
- Clean up old images
- Consider using different regions

### Debug Mode

```bash
# Enable verbose logging
./mirror.sh -d

# Check specific registry
DEBUG=1 source lib/ecr.sh && push_to_ecr docker.io/nginx:alpine
```

## Performance Tips

- **Parallel Jobs**: Start with 3, increase based on network/CPU
- **Regional Strategy**: Mirror to closest regions first
- **Image Size**: Prioritize smaller base images
- **Network**: Use instances with good bandwidth for faster transfers

## Security Considerations

- Store credentials in `.env` (never commit to git)
- Use service accounts with minimal required permissions
- Enable vulnerability scanning in target registries
- Regularly rotate access tokens and keys
- Consider using registry webhooks for automated mirroring

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new registry support
4. Update documentation
5. Submit a pull request

## License

MIT License - see LICENSE file for details

## Support

- **Documentation**: See `docs/` directory
- **Issues**: GitHub Issues
- **Discussions**: GitHub Discussions

## Roadmap

- [ ] Harbor registry support
- [ ] GitLab Container Registry support
- [ ] Helm chart mirroring
- [ ] Web UI for configuration
- [ ] Prometheus metrics export
- [ ] Webhook-based triggering
