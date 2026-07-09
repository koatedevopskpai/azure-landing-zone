# =============================================================================
# Root Module: SecondWave Azure Landing Zone
# =============================================================================
# ARCHITECTURE DECISION: This root module orchestrates the full CAF landing zone.
# Each concern is delegated to a specialised sub-module. This decomposition allows
# individual modules to be tested, versioned, and reused independently.
#
# SECURITY SAFEGUARD: The root module enforces a "secure-by-default" posture:
# - Private Endpoints enforced via Azure Policy (no public PaaS access)
# - Public IP on NICs denied by policy (no accidental internet-exposed VMs)
# - CMK enforced on all eligible resources (data sovereignty for FCA/PRA)
# - Key Vault denies all public network access
# - Forced tunnelling through Azure Firewall (all egress inspected)

# ---------------------------------------------------------------------------
# Data Sources
# ---------------------------------------------------------------------------
# ARCHITECTURE DECISION: Using data.azurerm_subscription avoids hardcoding the
# subscription resource ID. This pairs with the Management Group association below.

data "azurerm_client_config" "current" {}

data "azurerm_subscription" "current" {}

# ---------------------------------------------------------------------------
# Management Group Hierarchy
# ---------------------------------------------------------------------------
# ARCHITECTURE DECISION: CAF Management Group hierarchy provides policy-based
# governance at scale. Each level inherits policies from its parent, enabling
# broad controls at Platform level and environment-specific controls at LZs.
#
# Hierarchy:
#   SecondWave (root)
#   ├── Platform                     (IT shared services: connectivity, identity, logging)
#   ├── Landing Zones
#   │   ├── Landing-Zones-Dev        (developer experimentation, no real data)
#   │   ├── Landing-Zones-Staging    (pre-production, anonymised data)
#   │   └── Landing-Zones-Prod       (production, customer PII, regulated)
#   ├── Sandbox                      (ungoverned individual subscriptions)
#   └── Decommissioned               (drain-stop-delete lifecycle)
#
# SECURITY SAFEGUARD: Production and Staging are isolated MGs with separate
# policy sets. A configuration error in dev policies cannot propagate to prod.

module "management_groups" {
  source = "./modules/management-groups"

  tenant_id          = var.tenant_id
  subscription_id    = var.subscription_id
  root_mg_name       = var.root_mg_name
  environment_mgs    = {
    for k, v in var.environments : k => v.management_group_name
  }
}

# ---------------------------------------------------------------------------
# Hub Network
# ---------------------------------------------------------------------------
# ARCHITECTURE DECISION: Hub-Spoke over Virtual WAN for two reasons:
# 1. Cost predictability - VWAN routing units are expensive for a 350-person insurer
# 2. Simplicity - Hub-Spoke with Azure Firewall is well-understood by the ops team
# See docs/ADR/001-hub-spoke-over-virtual-wan.md for full rationale.
#
# ARCHITECTURE DECISION: Azure Firewall (not NSG-only) because:
# - NSGs are stateless for inbound, stateful for outbound but cannot inspect TLS
# - Azure Firewall provides FQDN filtering, threat intel, TLS inspection (Premium)
# - Centralised logging via diagnostics to Log Analytics
# - FCA/PRA require egress traffic inspection and logging for regulated workloads
# See docs/ADR/003-azure-firewall-over-nva.md.
#
# SECURITY SAFEGUARD: Forced tunnelling enabled - all spoke egress traffic is
# routed through Azure Firewall. This prevents data exfiltration via direct
# internet egress from workloads.

module "hub_network" {
  source = "./modules/hub-network"

  hub_vnet_cidr          = var.hub_vnet_cidr
  hub_subnet_prefixes    = var.hub_subnet_prefixes
  region                 = var.regions.primary
  firewall_sku           = var.firewall_sku
  firewall_threat_intel_mode = var.firewall_threat_intel_mode
  bastion_sku            = var.bastion_sku
  ddos_protection_enabled = var.ddos_protection_plan_enabled
  log_analytics_workspace_id = module.log_analytics.workspace_id
  spoke_vnets              = {
    for k, v in module.spoke_networks : k => {
      vnet_id = v.vnet_id
    }
  }
  tags                   = merge(var.tags, { Tier = "Hub" })
}

# ---------------------------------------------------------------------------
# Spoke Networks
# ---------------------------------------------------------------------------
# ARCHITECTURE DECISION: Each workload environment gets a dedicated spoke VNet.
# This provides network-level isolation - a compromise in dev cannot pivot to
# prod because there is no Layer 3 adjacency between spokes.
#
# SECURITY SAFEGUARD: UDRs force all spoke egress (0.0.0.0/0) through Azure
# Firewall next-hop. This is forced tunnelling at the vnet level, ensuring no
# workload can bypass security inspection.

module "spoke_networks" {
  source = "./modules/spoke-network"

  for_each = var.environments

  environment         = each.key
  spoke_cidr          = each.value.spoke_cidr
  region              = each.value.region
  hub_vnet_id         = module.hub_network.vnet_id
  firewall_private_ip = module.hub_network.firewall_private_ip
  log_analytics_workspace_id = module.log_analytics.workspace_id
  tags                = merge(var.tags, each.value.tags, { Spoke = each.key })
}

# ---------------------------------------------------------------------------
# Private DNS Zones
# ---------------------------------------------------------------------------
# ARCHITECTURE DECISION: Private DNS Zones over Azure Private DNS Resolver because:
# - Private Endpoints require Private DNS Zones for name resolution
# - The hub VNet is the resolution boundary - all spoke VNets link to these zones
# - This enables Private Link FQDNs (e.g., mystorage.blob.core.windows.net) to
#   resolve to the Private Endpoint IP within the hub-spoke topology
# See docs/ADR/002-private-endpoints-over-service-endpoints.md.
#
# SECURITY SAFEGUARD: DNS resolution for PaaS services stays within Azure backbone.
# No DNS query ever leaves Microsoft's network, preventing DNS-based data exfiltration.

module "private_dns" {
  source = "./modules/private-dns"

  private_dns_zones   = var.private_dns_zones
  hub_vnet_id         = module.hub_network.vnet_id
  spoke_vnet_ids      = {
    for k, v in module.spoke_networks : k => v.vnet_id
  }
  resource_group_name = module.hub_network.resource_group_name
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Log Analytics & Sentinel
# ---------------------------------------------------------------------------
# ARCHITECTURE DECISION: Single Log Analytics workspace for the entire landing zone.
# For a 350-person insurer, a single workspace is cost-effective and simplifies
# cross-resource KQL queries. Sentinel is enabled for SIEM capabilities to meet
# FCA/PRA cybersecurity requirements.

module "log_analytics" {
  source = "./modules/log-analytics"

  region              = var.regions.primary
  retention_days      = var.log_analytics_retention_days
  resource_group_name = module.hub_network.resource_group_name
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Key Vault
# ---------------------------------------------------------------------------
# ARCHITECTURE DECISION: Key Vault with RBAC authorization (not access policies)
# because RBAC integrates with Entra ID PIM for just-in-time privilege elevation.
# Soft-delete and purge protection are non-negotiable for FCA/PRA compliance.
#
# SECURITY SAFEGUARD: Network ACLs are set to deny all public traffic by default.
# Only Private Endpoint traffic is allowed. This is enforced at the network level
# in addition to Azure Policy enforcement.

module "key_vault" {
  source = "./modules/key-vault"

  region              = var.regions.primary
  resource_group_name = module.hub_network.resource_group_name
  tenant_id           = var.tenant_id
  log_analytics_workspace_id = module.log_analytics.workspace_id
  tags                = merge(var.tags, { Tier = "Security" })
}

# ---------------------------------------------------------------------------
# Entra ID Groups & PIM
# ---------------------------------------------------------------------------
# ARCHITECTURE DECISION: Four Entra ID groups aligned to SecondWave's value streams
# (Platform, Personal Lines, Commercial Lines, Data & Analytics). PIM eligibility
# ensures just-in-time privileged access - no standing admin rights.
#
# SECURITY SAFEGUARD: PIM requires approval for Platform-Admins group (break-glass
# scenarios). All other groups have activation max duration limited to 8 hours
# (one working shift). This aligns with FCA SYSC 6.1.4 (access management) and
# PRA SS2/21 (operational resilience).

module "entra_id" {
  source = "./modules/entra-id"

  groups = var.entra_groups
}

# ---------------------------------------------------------------------------
# Azure Policy
# ---------------------------------------------------------------------------
# ARCHITECTURE DECISION: Azure Policy enforces security guardrails at the
# Management Group level, out of reach of workload subscription owners.
# This ensures compliance without blocking velocity - policies are designed
# as "Deny" or "DeployIfNotExists" rather than manual audits.
#
# SECURITY SAFEGUARD: The "Deny public IP on NICs" policy prevents accidental
# exposure of VMs to the internet. Combined with forced tunnelling, there is
# no path for inbound internet traffic to reach workloads except through
# explicitly approved ingress paths (Azure Front Door / Application Gateway).

module "azure_policy" {
  source = "./modules/azure-policy"

  enforce_private_endpoints   = var.policy_enforce_private_endpoints
  deny_public_ip_on_nics      = var.policy_deny_public_ip_on_nics
  enforce_cmk                 = var.policy_enforce_cmk
  enforce_https_storage        = var.policy_enforce_https_storage
  mg_group_ids                = module.management_groups.group_ids
}
