# lib/acr.sh
#!/bin/bash

push_to_acr() {
   local source="$1"
   local repo tag target

   repo=$(echo "$source" | sed -n 's|[^/]*/\(.*\):.*|\1|p')
   tag=$(echo "$source" | sed -n 's|[^/]*/.*:\(.*\)|\1|p')

   for ACR_REGION in $(echo "${ACR_AZURE_REGIONS:-australiaeast}" | tr ',' '\n'); do
       ACR_NAME="${AZURE_ACR_NAME:-${AZURE_ACR_NAME_PREFIX:-org}acr${ACR_REGION}}"
       ACR_URL="${ACR_NAME}.azurecr.io"
       target="$ACR_URL/$repo:$tag"

       echo "Mirroring $source to ACR: $target"

       # Create ACR if it doesn't exist
       if ! az acr show --name "$ACR_NAME" --resource-group "$AZURE_RESOURCE_GROUP" >/dev/null 2>&1; then
           echo "Creating ACR: $ACR_NAME"
           az acr create \
               --name "$ACR_NAME" \
               --resource-group "$AZURE_RESOURCE_GROUP" \
               --location "$ACR_REGION" \
               --sku Standard \
               --admin-enabled false
       fi

       # Login to ACR
       az acr login --name "$ACR_NAME"

       # Copy image
       if crane copy "$source" "$target" --platform linux/amd64; then
           echo "✓ Successfully mirrored to ACR: $target"
       else
           echo "✗ Failed to mirror to ACR: $target"
           return 1
       fi
   done
}

authenticate_acr() {
   echo "Authenticating to Azure..."
   # Assumes Azure CLI is already logged in
   # For service principal: az login --service-principal -u $AZURE_CLIENT_ID -p $AZURE_CLIENT_SECRET --tenant $AZURE_TENANT_ID
}
