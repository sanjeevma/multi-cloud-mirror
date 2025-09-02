# lib/jfrog.sh
#!/bin/bash

push_to_jfrog() {
  local source="$1"
  local repo tag target

  repo=$(echo "$source" | sed -n 's|[^/]*/\(.*\):.*|\1|p')
  tag=$(echo "$source" | sed -n 's|[^/]*/.*:\(.*\)|\1|p')

  # JFrog URL format: https://yourcompany.jfrog.io/artifactory/docker-repo
  JFROG_DOCKER_URL="${JFROG_URL}/artifactory/${JFROG_REPOSITORY:-docker-local}"
  target="$JFROG_DOCKER_URL/$repo:$tag"

  echo "Mirroring $source to JFrog: $target"

  # Create repository if it doesn't exist (via JFrog CLI if available)
  if command -v jf >/dev/null 2>&1; then
      if ! jf rt repo-template docker-local-template.json >/dev/null 2>&1; then
          echo "Creating JFrog Docker repository: ${JFROG_REPOSITORY:-docker-local}"
          # Note: Repository creation typically done via JFrog admin UI or REST API
      fi
  fi

  # Copy image
  if crane copy "$source" "$target" --platform linux/amd64; then
      echo "✓ Successfully mirrored to JFrog: $target"
  else
      echo "✗ Failed to mirror to JFrog: $target"
      return 1
  fi
}

authenticate_jfrog() {
  echo "Authenticating to JFrog Artifactory..."

  # Validate required environment variables
  if [[ -z "$JFROG_URL" || -z "$JFROG_USER" || -z "$JFROG_TOKEN" ]]; then
      echo "Error: Missing JFrog credentials. Set JFROG_URL, JFROG_USER, and JFROG_TOKEN"
      return 1
  fi

  # Extract hostname from URL for crane auth
  JFROG_HOST=$(echo "$JFROG_URL" | sed -n 's|https\?://\([^/]*\).*|\1|p')

  # Login using crane
  if crane auth login -u "$JFROG_USER" -p "$JFROG_TOKEN" "$JFROG_HOST"; then
      echo "✓ Authenticated to JFrog: $JFROG_HOST"
  else
      echo "✗ Failed to authenticate to JFrog"
      return 1
  fi

  # Optional: Configure JFrog CLI if available
  if command -v jf >/dev/null 2>&1; then
      jf config add artifactory --url="$JFROG_URL" --user="$JFROG_USER" --password="$JFROG_TOKEN" --interactive=false
  fi
}
