# lib/gar.sh
#!/bin/bash

push_to_gar() {
  local source="$1"
  local repo tag target

  repo=$(echo "$source" | sed -n 's|[^/]*/\(.*\):.*|\1|p')
  tag=$(echo "$source" | sed -n 's|[^/]*/.*:\(.*\)|\1|p')

  for GCR_REGION in $(echo "${GCR_GCP_REGIONS:-australia-southeast1}" | tr ',' '\n'); do
      GAR_URL="$GCR_REGION-docker.pkg.dev/${GCP_PROJECT_ID}/k8s-assets"
      target="$GAR_URL/$repo:$tag"

      echo "Mirroring $source to GAR: $target"

      # Create repository if it doesn't exist
      if ! gcloud artifacts repositories describe k8s-assets \
          --location="$GCR_REGION" \
          --project="$GCP_PROJECT_ID" >/dev/null 2>&1; then
          echo "Creating GAR repository: k8s-assets in $GCR_REGION"
          gcloud artifacts repositories create k8s-assets \
              --repository-format=docker \
              --location="$GCR_REGION" \
              --project="$GCP_PROJECT_ID"
      fi

      # Copy image
      if crane copy "$source" "$target" --platform linux/amd64; then
          echo "✓ Successfully mirrored to GAR: $target"
      else
          echo "✗ Failed to mirror to GAR: $target"
          return 1
      fi
  done
}

authenticate_gar() {
  echo "Authenticating to Google Artifact Registry..."

  # Configure service account impersonation if specified
  if [[ -n "$GCP_SERVICE_ACCOUNT" ]]; then
      gcloud config set auth/impersonate_service_account "$GCP_SERVICE_ACCOUNT" --quiet
  fi

  # Configure Docker auth for each GAR region
  for GCR_REGION in $(echo "${GCR_GCP_REGIONS:-australia-southeast1}" | tr ',' '\n'); do
      gcloud auth configure-docker "$GCR_REGION-docker.pkg.dev" --quiet
      echo "✓ Configured Docker auth for GAR region: $GCR_REGION"
  done
}
