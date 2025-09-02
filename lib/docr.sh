# lib/docr.sh
#!/bin/bash

push_to_docr() {
  local source="$1"
  local repo tag target

  repo=$(echo "$source" | sed -n 's|[^/]*/\(.*\):.*|\1|p')
  tag=$(echo "$source" | sed -n 's|[^/]*/.*:\(.*\)|\1|p')

  for DOCR_REGION in $(echo "${DOCR_REGIONS:-nyc3}" | tr ',' '\n'); do
      DOCR_URL="registry.digitalocean.com/${DOCR_REGISTRY_NAME}"
      target="$DOCR_URL/$repo:$tag"

      echo "Mirroring $source to DOCR: $target"

      # Copy image
      if crane copy "$source" "$target" --platform linux/amd64; then
          echo "✓ Successfully mirrored to DOCR: $target"
      else
          echo "✗ Failed to mirror to DOCR: $target"
          return 1
      fi
  done
}

authenticate_docr() {
  echo "Authenticating to DigitalOcean Container Registry..."

  # Get DigitalOcean auth token and login
  if [[ -n "$DOCR_TOKEN" ]]; then
      echo "$DOCR_TOKEN" | crane auth login registry.digitalocean.com -u unused --password-stdin
  else
      echo "Error: DOCR_TOKEN environment variable not set"
      return 1
  fi
}
