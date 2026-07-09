# =============================================================================
# Key Vault Module - Secrets & Key Management
# =============================================================================
# ARCHITECTURE DECISION: Key Vault uses RBAC authorization (not legacy access
# policies) because:
# 1. RBAC integrates natively with Entra ID and PIM for just-in-time elevation
# 2. Access policies are a legacy construct that require separate management
# 3. RBAC allows fine-grained role assignments (Key Vault Secrets User vs. Officer)
# 4. Azure Policy can audit RBAC assignments but not access policies
#
# SECURITY SAFEGUARD: Key Vault denies all public network access by default.
# Only Private Endpoint traffic is allowed. This is the most critical security
# control for Key Vault - if the vault is publicly accessible, a leaked key
# or connection string can be used from anywhere on the internet.
#
# Additional safeguards:
# - Soft-delete enabled (90-day retention for accidental deletion recovery)
# - Purge protection enabled (prevents permanent deletion before retention expires)
# - RBAC only (no access policies)
# - Diagnostic logs sent to Log Analytics for audit

resource "azurerm_key_vault" "this" {
  name                          = "kv-platform-${var.region}"
  location                      = var.region
  resource_group_name           = var.resource_group_name
  tenant_id                     = var.tenant_id
  sku_name                      = "standard"

  # SECURITY SAFEGUARD: Soft-delete and purge protection are required for
  # FCA/PRA compliance. Soft-delete allows recovery of accidentally deleted
  # keys/secrets within the retention window. Purge protection prevents
  # permanent deletion (even by administrators) until the retention expires.
  soft_delete_retention_days    = 90
  purge_protection_enabled      = true

  # SECURITY SAFEGUARD: RBAC-only authorization. Setting role_based_access_control_enabled
  # to true and not configuring any access_policies ensures no legacy access
  # policy can bypass RBAC controls.
  enable_rbac_authorization     = true

  # SECURITY SAFEGUARD: Public network access is denied. Key Vault is only
  # accessible via Private Endpoint within the hub-spoke VNet topology.
  public_network_access_enabled = false

  tags                          = var.tags
}

# ---------------------------------------------------------------------------
# Key Vault Private Endpoint
# ---------------------------------------------------------------------------
# ARCHITECTURE DECISION: A Private Endpoint is created for Key Vault in the
# hub network. This ensures all vault access stays within the Azure backbone
# and never traverses the public internet.
#
# SECURITY SAFEGUARD: The private_dns_zone_group associates the PE with the
# privatelink.vaultcore.azure.net zone, ensuring the vault URI resolves to
# the private IP within the hub-spoke topology.

data "azurerm_virtual_network" "hub" {
  name                = "vnet-hub-${var.region}"
  resource_group_name = "rg-hub-network-${var.region}"
}

data "azurerm_subnet" "private_endpoints" {
  name                 = "snet-management-${var.region}"
  resource_group_name  = "rg-hub-network-${var.region}"
  virtual_network_name = data.azurerm_virtual_network.hub.name
}

resource "azurerm_private_endpoint" "key_vault" {
  name                = "pe-${azurerm_key_vault.this.name}"
  location            = var.region
  resource_group_name = var.resource_group_name
  subnet_id           = data.azurerm_subnet.private_endpoints.id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-keyvault"
    private_connection_resource_id = azurerm_key_vault.this.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  private_dns_zone_group {
    name                 = "dns-zone-group-keyvault"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.vault.id]
  }
}

data "azurerm_private_dns_zone" "vault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.resource_group_name
}

# ---------------------------------------------------------------------------
# RBAC Role Assignments
# ---------------------------------------------------------------------------
# ARCHITECTURE DECISION: Platform-Admins group gets "Key Vault Administrator"
# role (full management). Individual workload teams get "Key Vault Secrets User"
# (read-only) via workload-specific assignments not shown here.
#
# SECURITY SAFEGUARD: Role assignments are scoped to the Key Vault resource,
# not the subscription. This follows least-privilege - a Platform Admin can
# manage this vault but cannot see secrets in other vaults.

data "azuread_group" "platform_admins" {
  display_name = "Platform-Admins"
}

resource "azurerm_role_assignment" "platform_admins_key_vault" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azuread_group.platform_admins.object_id
}

# ---------------------------------------------------------------------------
# Diagnostic Settings
# ---------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "key_vault" {
  name                       = "diag-keyvault-to-law"
  target_resource_id         = azurerm_key_vault.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "AuditEvent"
  }
  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
