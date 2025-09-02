# lib/ecr.sh
#!/bin/bash

push_to_ecr() {
  local source="$1"
  local repo tag target

  repo=$(echo "$source" | sed -n 's|[^/]*/\(.*\):.*|\1|p')
  tag=$(echo "$source" | sed -n 's|[^/]*/.*:\(.*\)|\1|p')
  target="$ECR_URL/$repo:$tag"

  echo "Mirroring $source to ECR: $target"

  # Create repository if it doesn't exist
  if ! aws ecr describe-repositories --repository-name "$repo" --region "$ECR_MIRROR_REGION" >/dev/null 2>&1; then
      echo "Creating ECR repository: $repo"
      aws ecr create-repository \
          --repository-name "$repo" \
          --image-scanning-configuration scanOnPush=true \
          --region "$ECR_MIRROR_REGION"
  fi

  # Copy image
  if crane copy "$source" "$target" --platform linux/amd64; then
      echo "✓ Successfully mirrored to ECR: $target"
  else
      echo "✗ Failed to mirror to ECR: $target"
      return 1
  fi
}

authenticate_ecr() {
  echo "Authenticating to AWS ECR regions..."

  for ECR_MIRROR_REGION in $(echo "${ECR_MIRROR_AWS_REGIONS:-ap-southeast-2}" | tr ',' '\n'); do
      TOKEN=$(aws ecr get-login-password --region "$ECR_MIRROR_REGION")
      AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
      export ECR_URL="$AWS_ACCOUNT_ID.dkr.ecr.$ECR_MIRROR_REGION.amazonaws.com"

      crane auth login -u AWS -p "$TOKEN" "$ECR_URL"
      echo "✓ Authenticated to ECR region: $ECR_MIRROR_REGION"
  done
}
