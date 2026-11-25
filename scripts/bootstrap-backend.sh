#!/usr/bin/env bash
# Creates a hardened Azure Storage account for Terraform remote state.
# Usage: SUB=<subscription-id> SA=<globally-unique-name> ./scripts/bootstrap-backend.sh
set -euo pipefail

: "${SUB:?Set SUB to the (management) subscription ID}"
: "${SA:?Set SA to a globally unique storage account name (3-24 lowercase alnum)}"
LOCATION="${LOCATION:-westeurope}"
RG="${RG:-rg-tfstate-alz}"
CONTAINER="${CONTAINER:-tfstate}"

az account set --subscription "$SUB"
az group create --name "$RG" --location "$LOCATION" \
  --tags Purpose=terraform-state ManagedBy=bootstrap-script CostCenter=platform Environment=prod Owner=platform-team >/dev/null

az storage account create --name "$SA" --resource-group "$RG" --location "$LOCATION" \
  --sku Standard_GRS --kind StorageV2 --https-only true --min-tls-version TLS1_2 \
  --allow-blob-public-access false --allow-shared-key-access false >/dev/null

az storage account blob-service-properties update --account-name "$SA" --resource-group "$RG" \
  --enable-versioning true \
  --enable-delete-retention true --delete-retention-days 30 \
  --enable-container-delete-retention true --container-delete-retention-days 30 >/dev/null

SCOPE=$(az storage account show --name "$SA" --resource-group "$RG" --query id -o tsv)
ME=$(az ad signed-in-user show --query id -o tsv)
az role assignment create --assignee-object-id "$ME" --assignee-principal-type User \
  --role "Storage Blob Data Contributor" --scope "$SCOPE" >/dev/null

echo "Waiting for RBAC propagation..."; sleep 45
az storage container create --name "$CONTAINER" --account-name "$SA" --auth-mode login >/dev/null
az lock create --name protect-state --lock-type CanNotDelete --resource-group "$RG" >/dev/null

cat <<OUT
Done. Create backend.hcl:
  resource_group_name  = "$RG"
  storage_account_name = "$SA"
  container_name       = "$CONTAINER"
  key                  = "landing-zone.tfstate"
  use_azuread_auth     = true
OUT
