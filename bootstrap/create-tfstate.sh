#!/usr/bin/env bash
# Creates the Azure storage account that holds Terraform state for two-tier-dr.
set -euo pipefail

RG="rg-tfstate"
LOCATION="centralus"       
CONTAINER="tfstate"
APP_NAME="gh-two-tier-dr"  

APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv)
if [ -z "$APP_ID" ]; then
  echo "App registration $APP_NAME not found. Run the OIDC setup first." >&2
  exit 1
fi

echo "Resource group..."
az group create -n "$RG" -l "$LOCATION" -o none

echo "Storage account..."
SA=$(az storage account list -g "$RG" --query "[0].name" -o tsv)
if [ -z "$SA" ]; then
  SA="sttfstate$RANDOM"
  az storage account create -n "$SA" -g "$RG" -l "$LOCATION" \
    --sku Standard_GRS --min-tls-version TLS1_2 \
    --allow-blob-public-access false -o none
fi
SA_ID=$(az storage account show -n "$SA" -g "$RG" --query id -o tsv)

echo "Versioning and soft delete..."
az storage account blob-service-properties update --account-name "$SA" -g "$RG" \
  --enable-versioning true \
  --enable-delete-retention true --delete-retention-days 30 \
  --enable-container-delete-retention true --container-delete-retention-days 30 -o none

echo "Container..."
if [ "$(az storage container-rm exists --storage-account "$SA" -g "$RG" -n "$CONTAINER" --query exists -o tsv)" != "true" ]; then
  az storage container-rm create --storage-account "$SA" -g "$RG" -n "$CONTAINER" -o none
fi

echo "Pipeline access..."
if [ -z "$(az role assignment list --assignee "$APP_ID" --role "Storage Blob Data Contributor" --scope "$SA_ID" --query "[0].id" -o tsv)" ]; then
  az role assignment create --assignee "$APP_ID" --role "Storage Blob Data Contributor" --scope "$SA_ID" -o none
fi

echo "Delete lock..."
az lock create --name tfstate-cannot-delete --lock-type CanNotDelete \
  -g "$RG" --resource "$SA" --resource-type Microsoft.Storage/storageAccounts -o none

echo
echo "Done. Use these values in each stack's backend:"
echo "  resource_group_name  = \"$RG\""
echo "  storage_account_name = \"$SA\""
echo "  container_name       = \"$CONTAINER\""