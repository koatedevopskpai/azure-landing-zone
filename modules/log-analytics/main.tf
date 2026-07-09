# =============================================================================
# Log Analytics & Sentinel Module - Centralised Security Monitoring
# =============================================================================
# ARCHITECTURE DECISION: Single Log Analytics workspace for the entire landing
# zone. For SecondWave (350-person insurer), a single workspace simplifies:
# 1. Cross-resource KQL queries (Firewall + Key Vault + AKS logs in one query)
# 2. Cost management - one commitment tier vs. splitting across workspaces
# 3. Sentinel enablement - one workspace to monitor, one UI pane
#
# SECURITY SAFEGUARD: Sentinel is enabled for SIEM capabilities to meet
# FCA/PRA cybersecurity requirements. The workspace retention is set to 730
# days (2 years) to align with regulatory record-keeping requirements.

resource "azurerm_resource_group" "this" {
  name     = "rg-log-analytics-${var.region}"
  location = var.region
  tags     = var.tags
}

# ---------------------------------------------------------------------------
# Log Analytics Workspace
# ---------------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "this" {
  name                          = "log-${var.region}"
  location                      = var.region
  resource_group_name           = azurerm_resource_group.this.name
  sku                           = "PerGB2018"
  retention_in_days             = var.retention_days
  daily_quota_gb                = null
  internet_ingestion_enabled    = true
  internet_query_enabled        = true
  reservation_capability_enabled = false
  tags                          = var.tags
}

# ---------------------------------------------------------------------------
# Sentinel (Microsoft Sentinel)
# ---------------------------------------------------------------------------
# ARCHITECTURE DECISION: Sentinel is enabled on the Log Analytics workspace
# as a unified SIEM. For a regulated UK insurer, Sentinel provides:
# - 90-day free data retention for security investigations
# - UEBA (User and Entity Behavior Analytics) for insider threat detection
# - SOAR (Security Orchestration, Automation, and Response) via Logic Apps
# - Built-in analytics rules for Azure security events

resource "azurerm_sentinel_log_analytics_workspace_onboarding" "this" {
  workspace_id = azurerm_log_analytics_workspace.this.id
}

# ---------------------------------------------------------------------------
# Sentinel Alert Rules
# ---------------------------------------------------------------------------
# ARCHITECTURE DECISION: Built-in analytics rules are enabled for common
# Azure security events. Additional custom rules are defined in
# observability/log-alert-rules.json.

resource "azurerm_sentinel_alert_rule_nrt" "firewall_denied" {
  name                       = "Firewall-Denied-Connections"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  display_name               = "Firewall Denied Connections"
  description                = "Alerts on denied outbound connections from Azure Firewall."
  severity                   = "Medium"
  enabled                    = true

  query = <<-QUERY
    AzureDiagnostics
    | where Category == "AzureFirewallNetworkRule"
    | where action_s == "Deny"
    | summarize DeniedCount = count() by src_ip_s, dst_ip_s, dst_port_d, protocol_s, bin(TimeGenerated, 5m)
    | where DeniedCount > 10
  QUERY

  event_grouping {
    aggregation_kind = "SingleAlert"
  }

  tactics = ["Exfiltration", "CommandAndControl"]
}

resource "azurerm_sentinel_alert_rule_nrt" "keyvault_access" {
  name                       = "KeyVault-Access-Change"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  display_name               = "Key Vault Access Changes"
  description                = "Alerts on Key Vault audit events indicating access changes."
  severity                   = "High"
  enabled                    = true

  query = <<-QUERY
    AzureDiagnostics
    | where ResourceType == "VAULTS"
    | where OperationName in ("VaultGet", "VaultList", "VaultCreate", "VaultDelete", "VaultPurge")
    | project TimeGenerated, OperationName, CallerIPAddress, Identity, ResourceId
  QUERY

  event_grouping {
    aggregation_kind = "SingleAlert"
  }

  tactics = ["CredentialAccess", "Persistence"]
}

resource "azurerm_sentinel_alert_rule_nrt" "policy_non_compliance" {
  name                       = "Policy-Non-Compliance"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  display_name               = "Azure Policy Non-Compliance"
  description                = "Alerts when resources are non-compliant with Azure Policy."
  severity                   = "Medium"
  enabled                    = true

  query = <<-QUERY
    AzureActivity
    | where CategoryValue == "Policy"
    | where OperationNameValue contains "nonCompliant"
    | project TimeGenerated, ResourceId, PolicyDefinitionName, PolicyAssignmentName, Caller
  QUERY

  event_grouping {
    aggregation_kind = "SingleAlert"
  }

  tactics = ["DefenseEvasion"]
}

# ---------------------------------------------------------------------------
# Diagnostic Settings for Platform Resources
# ---------------------------------------------------------------------------
# ARCHITECTURE DECISION: Diagnostic settings are configured per-resource
# (Firewall, VNet, Key Vault) in their respective modules. This module
# creates the Log Analytics workspace used as the target.

# ---------------------------------------------------------------------------
# Solution Pack (Optional)
# ---------------------------------------------------------------------------
# Note: Azure Monitor solutions like "Security" and "AzureActivity" can be
# added via azurerm_log_analytics_solution resource.
