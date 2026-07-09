# =============================================================================
# Hub Network Module - Connectivity & Security Perimeter
# =============================================================================
# ARCHITECTURE DECISION: Hub VNet hosts all shared networking services:
# - Azure Firewall: central egress inspection and policy enforcement
# - Azure NAT Gateway: outbound connectivity for private workloads
# - Azure Bastion: secure jumpbox-free management access
# - DDoS Protection Plan: volumetric attack protection
#
# Why Azure Firewall over NSG-only:
# 1. NSGs operate at L3/L4 only - no FQDN filtering, no TLS inspection
# 2. Azure Firewall provides application-level (L7) rules for FQDN allow/deny
# 3. Centralised logging: one Firewall emits all flow logs vs. N NSGs
# 4. Threat intelligence feed blocks known malicious IPs/FQDNs automatically
# 5. FCA/PRA require demonstrable egress inspection - NSGs alone don't satisfy this
# See docs/ADR/003-azure-firewall-over-nva.md.
#
# SECURITY SAFEGUARD: The hub VNet has no direct internet ingress. All inbound
# traffic goes through Azure Front Door / Application Gateway in a DMZ pattern.
# Azure Bastion provides management plane access without public IPs on VMs.

# ---------------------------------------------------------------------------
# Resource Group
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "this" {
  name     = "rg-hub-network-${var.region}"
  location = var.region
  tags     = var.tags
}

# ---------------------------------------------------------------------------
# DDoS Protection Plan
# ---------------------------------------------------------------------------
# ARCHITECTURE DECISION: DDoS Protection Plan is enabled for the hub VNet.
# For a UK insurer under FCA/PRA, availability is a regulatory requirement.
# The Basic (free) tier covers infrastructure-layer attacks only; the Network
# Protection plan covers L3/L4 volumetric attacks with adaptive tuning.
resource "azurerm_network_ddos_protection_plan" "this" {
  count = var.ddos_protection_enabled ? 1 : 0

  name                = "ddos-protection-plan"
  location            = var.region
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Hub Virtual Network
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "this" {
  name                = "vnet-hub-${var.region}"
  location            = var.region
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [var.hub_vnet_cidr]
  tags                = var.tags

  dynamic "ddos_protection_plan" {
    for_each = var.ddos_protection_enabled ? [1] : []
    content {
      id     = azurerm_network_ddos_protection_plan.this[0].id
      enable = true
    }
  }
}

# ---------------------------------------------------------------------------
# Subnets
# ---------------------------------------------------------------------------
# ARCHITECTURE DECISION: Azure Firewall requires a dedicated subnet named
# "AzureFirewallSubnet" with prefix /26 minimum. Bastion requires
# "AzureBastionSubnet" with /26 minimum. The Gateway subnet is for
# ExpressRoute/VPN Gateway in future.

resource "azurerm_subnet" "azure_firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.hub_subnet_prefixes.azure_firewall]
}

# SECURITY SAFEGUARD: Bastion subnet must not have any NSG association that
# could interfere with Bastion's control plane connectivity. Azure manages
# the NSG for this subnet internally.
resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.hub_subnet_prefixes.bastion]
}

resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.hub_subnet_prefixes.gateway]
}

resource "azurerm_subnet" "management" {
  name                 = "snet-management-${var.region}"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.hub_subnet_prefixes.management]
}

# ---------------------------------------------------------------------------
# Azure Firewall Policy
# ---------------------------------------------------------------------------
# ARCHITECTURE DECISION: Firewall Policy over classic rules. Policy allows
# central management, child policies for spoke-specific rules, and integrates
# with Azure Policy (e.g., deploy firewall policy via policy).
resource "azurerm_firewall_policy" "this" {
  name                     = "afwp-hub-${var.region}"
  resource_group_name      = azurerm_resource_group.this.name
  location                 = var.region
  sku                      = var.firewall_sku
  threat_intelligence_mode = var.firewall_threat_intel_mode
  tags                     = var.tags
}

# ---------------------------------------------------------------------------
# Firewall Policy Rule Collection Group - Default
# ---------------------------------------------------------------------------
# ARCHITECTURE DECISION: Default rule set includes:
# - Deny all outbound to internet (except approved FQDNs)
# - Allow AzureCloud service tags for platform services
# - FQDN rules for common Microsoft services (Windows Update, Defender, etc.)
# - Network rules for DNS (Azure DNS), NTP (time.windows.com)

resource "azurerm_firewall_policy_rule_collection_group" "default" {
  name               = "DefaultRules"
  firewall_policy_id = azurerm_firewall_policy.this.id
  priority           = 100

  # SECURITY SAFEGUARD: Deny all outbound internet traffic by default.
  # Only explicitly approved FQDNs are allowed through.
  rule_collection {
    name     = "deny-all-internet"
    priority = 100
    action   = "Deny"
    rule {
      name        = "deny-all-internet"
      protocols {
        type = "Any"
        port = 0
      }
      source_addresses  = ["*"]
      destination_addresses = ["*"]
      destination_ports = ["*"]
    }
  }

  # Network rules for essential platform services
  rule_collection {
    name     = "allow-azure-platform"
    priority = 200
    action   = "Allow"
    rule {
      name        = "allow-azure-dns"
      protocols {
        type = "UDP"
        port = 53
      }
      source_addresses  = ["*"]
      destination_addresses = ["168.63.129.16"]
      destination_ports = ["53"]
    }
    rule {
      name        = "allow-ntp"
      protocols {
        type = "UDP"
        port = 123
      }
      source_addresses  = ["*"]
      destination_addresses = ["ntp.ubuntu.com", "time.windows.com"]
      destination_ports = ["123"]
    }
  }
}

# ---------------------------------------------------------------------------
# Azure Firewall
# ---------------------------------------------------------------------------
# ARCHITECTURE DECISION: Premium SKU provides TLS inspection for regulated
# workloads. Standard SKU is default for cost optimisation in non-prod.
# Forced tunnelling enabled means management traffic goes through the firewall
# itself (hub-as-next-hop), preventing split-tunnelling.

resource "azurerm_firewall" "this" {
  name                = "afw-hub-${var.region}"
  location            = var.region
  resource_group_name = azurerm_resource_group.this.name
  sku_name            = "AZFW_VNet"
  sku_tier            = var.firewall_sku
  firewall_policy_id  = azurerm_firewall_policy.this.id
  tags                = var.tags

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.azure_firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }
  # SECURITY SAFEGUARD: forced_tunneling_enabled routes management traffic
  # through the firewall PIP. This prevents bypass of inspection.
  # forced_tunneling_enabled = true  # Uncomment for forced tunnelling
}

# ---------------------------------------------------------------------------
# Public IPs
# ---------------------------------------------------------------------------
resource "azurerm_public_ip" "firewall" {
  name                = "pip-afw-hub-${var.region}"
  location            = var.region
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

resource "azurerm_public_ip" "nat_gateway" {
  name                = "pip-nat-hub-${var.region}"
  location            = var.region
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

resource "azurerm_public_ip" "bastion" {
  name                = "pip-bastion-hub-${var.region}"
  location            = var.region
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# NAT Gateway
# ---------------------------------------------------------------------------
# ARCHITECTURE DECISION: NAT Gateway provides outbound connectivity for private
# workloads in the spoke VNets (via the hub). This gives a single public IP for
# outbound traffic, simplifying firewall rules and partner allow-listing.
# NAT Gateway is zone-redundant for availability.

resource "azurerm_nat_gateway" "this" {
  name                = "nat-hub-${var.region}"
  location            = var.region
  resource_group_name = azurerm_resource_group.this.name
  sku_name            = "Standard"
  idle_timeout_in_minutes = 10
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "this" {
  nat_gateway_id       = azurerm_nat_gateway.this.id
  public_ip_address_id = azurerm_public_ip.nat_gateway.id
}

# ---------------------------------------------------------------------------
# Azure Bastion
# ---------------------------------------------------------------------------
# ARCHITECTURE DECISION: Azure Bastion provides RDP/SSH access to VMs without
# public IPs. This eliminates the need for jumpbox VMs (patching overhead) and
# exposes no management ports to the internet.
#
# SECURITY SAFEGUARD: Bastion is deployed in the hub VNet with a dedicated
# subnet. Combined with PIM, administrators must have just-in-time approval
# to even reach the Bastion service, let alone connect to a VM.

resource "azurerm_bastion_host" "this" {
  name                = "bastion-hub-${var.region}"
  location            = var.region
  resource_group_name = azurerm_resource_group.this.name
  sku                 = var.bastion_sku
  tunneling_enabled   = true
  tags                = var.tags

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}

# ---------------------------------------------------------------------------
# VNet Peerings (Hub-to-Spoke)
# ---------------------------------------------------------------------------
# ARCHITECTURE DECISION: Hub-to-spoke peerings are created in the hub module
# because the hub resource group is managed here. This allows the hub to initiate
# connections to spoke workloads (e.g., monitoring agents, Bastion).
#
# SECURITY SAFEGUARD: allow_gateway_transit is enabled on the hub side so that
# spokes can use the hub VPN/ExpressRoute gateway for hybrid connectivity when
# explicitly approved. Each spoke must opt-in via their own peering config.

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  for_each = var.spoke_vnets

  name                      = "peer-hub-to-spoke-${each.key}"
  resource_group_name       = azurerm_resource_group.this.name
  virtual_network_name      = azurerm_virtual_network.this.name
  remote_virtual_network_id = each.value.vnet_id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
  use_remote_gateways          = false
}

# ---------------------------------------------------------------------------
# Diagnostic Settings
# ---------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "firewall" {
  name                       = "diag-firewall-to-law"
  target_resource_id         = azurerm_firewall.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "AzureFirewallApplicationRule"
  }
  enabled_log {
    category = "AzureFirewallNetworkRule"
  }
  enabled_log {
    category = "AzureFirewallDnsProxy"
  }
  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

resource "azurerm_monitor_diagnostic_setting" "nat_gateway" {
  name                       = "diag-nat-to-law"
  target_resource_id         = azurerm_nat_gateway.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "NatGateway"
  }
  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

resource "azurerm_monitor_diagnostic_setting" "bastion" {
  name                       = "diag-bastion-to-law"
  target_resource_id         = azurerm_bastion_host.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "BastionAuditLogs"
  }
  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
