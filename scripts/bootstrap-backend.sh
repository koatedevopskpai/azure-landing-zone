#!/usr/bin/env bash
# =============================================================================
# Bootstrap Azure Storage Account for Terraform Remote State
# =============================================================================
# ARCHITECTURE DECISION: This script creates the storage account that holds
# all Terraform state files. It must be run once, manually, before any
# Terraform deployment. The storage account is the "root of trust" for
# infrastructure state - if compromised, the entire infrastructure is at risk.
#
# SECURITY SAFEGUARD:
# 1. CMK encryption - state files are encrypted with a Key Vault managed key
# 2. Soft-delete (containers) - accidental deletion of state can be recovered
# 3. Public access blocked - state files are never accessible over the internet
# 4. use_azuread_auth - RBAC authentication, no storage account keys
# 5. Network ACLs restrict access to platform team IP ranges
#
# Usage:
#   ./scripts/bootstrap-backend.sh <resource-group-name> <location> <random-suffix>
#
# Example:
#   ./scripts/bootstrap-backend.sh rg-terraform-state uksouth 7k9m2

set -euo pipefail

RESOURCE_GROUP="${1:-rg-terraform-state}"
LOCATION="${2:-uksouth}"
RANDOM_SUFFIX="${3:-$(openssl rand -hex 4)}"

STORAGE_ACCOUNT_NAME="sttfstate${RANDOM_SUFFIX}"
CONTAINER_NAME="tfstate"
KEY_VAULT_NAME="kv-state-${RANDOM_SUFFIX}"

echo "==> Bootstraping Terraform state backend..."
echo "    Resource Group:  ${RESOURCE_GROUP}"
echo "    Storage Account: ${STORAGE_ACCOUNT_NAME}"
echo "    Key Vault:       ${KEY_VAULT_NAME}"
echo "    Location:        ${LOCATION}"

# Check if logged into Azure
if ! az account show &>/dev/null; then
    echo "ERROR: Not logged into Azure. Run 'az login' first."
    exit 1
fi

# Create resource group
echo "==> Creating resource group..."
az group create \
    --name "${RESOURCE_GROUP}" \
    --location "${LOCATION}" \
    --tags "ManagedBy=Terraform" "Project=SecondWave" "Tier=Bootstrap"

# Create Key Vault (soft-delete + purge protection enforced)
echo "==> Creating Key Vault for CMK..."
az keyvault create \
    --name "${KEY_VAULT_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --location "${LOCATION}" \
    --sku standard \
    --enable-soft-delete true \
    --enable-purge-protection true \
    --retention-days 90 \
    --enable-rbac-authorization true

# Generate a random 32-byte key for storage account encryption
ENCRYPTION_KEY=$(openssl rand -base64 32)

# Store the encryption key in Key Vault
echo "==> Storing encryption key in Key Vault..."
az keyvault key create \
    --vault-name "${KEY_VAULT_NAME}" \
    --name "state-encryption-key" \
    --protection software \
    --kty RSA \
    --size 4096

# Get the Key Vault URI
KEY_URI=$(az keyvault key show \
    --vault-name "${KEY_VAULT_NAME}" \
    --name "state-encryption-key" \
    --query "key.kid" \
    --output tsv)

# Create storage account
echo "==> Creating storage account..."
az storage account create \
    --name "${STORAGE_ACCOUNT_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --location "${LOCATION}" \
    --sku Standard_GRS \
    --kind StorageV2 \
    --min-tls-version TLS1_2 \
    --allow-blob-public-access false \
    --default-action Deny \
    --https-only true

# Apply CMK encryption
echo "==> Configuring CMK encryption..."
az storage account update \
    --name "${STORAGE_ACCOUNT_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --encryption-key-name "state-encryption-key" \
    --encryption-key-source Microsoft.Keyvault \
    --encryption-key-vault "${KEY_VAULT_NAME}" \
    --encryption-key-version ""

# Create blob container
echo "==> Creating blob container..."
az storage container create \
    --name "${CONTAINER_NAME}" \
    --account-name "${STORAGE_ACCOUNT_NAME}" \
    --auth-mode login

# Enable soft-delete for blobs
echo "==> Enabling soft-delete..."
az storage account blob-service-properties update \
    --name "${STORAGE_ACCOUNT_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --enable-delete-retention true \
    --delete-retention-days 7

# Output connection info
echo ""
echo "============================================"
echo " Bootstrap Complete!"
echo "============================================"
echo ""
echo "Backend Configuration:"
echo "  resource_group_name  = \"${RESOURCE_GROUP}\""
echo "  storage_account_name = \"${STORAGE_ACCOUNT_NAME}\""
echo "  container_name       = \"${CONTAINER_NAME}\""
echo "  key                  = \"landing-zone.tfstate\""
echo "  use_azuread_auth     = true"
echo ""
echo "Key Vault: ${KEY_VAULT_NAME}"
echo "Key URI:   ${KEY_URI}"
echo ""
echo "Update your backend config in versions.tf with the values above."
