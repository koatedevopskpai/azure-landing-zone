# =============================================================================
# Spoke Network Module - Workload Isolation with Forced Tunnelling
# =============================================================================
# ARCHITECTURE DECISION: Each workload spoke is a dedicated VNet that peers to
# the hub for transitive routing. Spokes do NOT peer with each other (no
# transitive routing through hub by default - use Azure Firewall as router if
# needed).
#
# SECURITY SAFEGUARD: Forced tunnelling is implemented via a UDR on the spoke
# subnets that routes 0.0.0.0/0 to the Azure Firewall private IP as next-hop.
# This ensures:
# 1. All outbound traffic is inspected by the firewall
# 2. No workload can bypass security controls by deploying its own internet gateway
# 3. Data exfiltration is prevented - even compromised workloads must pass through
#    the firewall's deny rules
# 4. Compliance with FCA SYSC 6.1 (IT security) logging all egress connections

resource "azurerm_resource_group" "this" {
  name     = "rg-spoke-${var.environment}-${var.region}"
  location = var.region
  tags     = var.tags
}

# ---------------------------------------------------------------------------
# Spoke Virtual Network
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "this" {
  name                = "vnet-spoke-${var.environment}-${var.region}"
  location            = var.region
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [var.spoke_cidr]
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Workload Subnet
# ---------------------------------------------------------------------------
# ARCHITECTURE DECISION: A single workload subnet is created. Workloads that
# need multiple subnets (e.g., App, Data, Web tiers) should extend this module
# or create additional subnets as needed.
resource "azurerm_subnet" "workload" {
  name                 = "snet-workload-${var.environment}-${var.region}"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [cidrsubnet(var.spoke_cidr, 8, 0)]
}

# ---------------------------------------------------------------------------
# Route Table & UDR (Forced Tunnelling)
# ---------------------------------------------------------------------------
# SECURITY SAFEGUARD: The default route (0.0.0.0/0) is set to the Azure Firewall
# private IP as virtual appliance next-hop. This is the mechanism for forced
# tunnelling. The route is associated with every subnet in the spoke.

resource "azurerm_route_table" "this" {
  name                          = "rt-spoke-${var.environment}-${var.region}"
  location                      = var.region
  resource_group_name           = azurerm_resource_group.this.name
  disable_bgp_route_propagation = false
  tags                          = var.tags
}

resource "azurerm_route" "to_firewall" {
  name                   = "default-to-firewall"
  resource_group_name    = azurerm_resource_group.this.name
  route_table_name       = azurerm_route_table.this.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = var.firewall_private_ip
}

# ARCHITECTURE DECISION: A /32 route for Azure DNS (168.63.129.16) ensures DNS
# queries don't go through the firewall. Azure DNS is an infrastructure service
# that must be directly accessible from VMs for name resolution to work.
# Without this exception, DNS would be force-tunnelled and break.
resource "azurerm_route" "azure_dns" {
  name                   = "azure-dns-direct"
  resource_group_name    = azurerm_resource_group.this.name
  route_table_name       = azurerm_route_table.this.name
  address_prefix         = "168.63.129.16/32"
  next_hop_type          = "Internet"
}

# SECURITY SAFEGUARD: Routes for Azure platform services (management, metadata)
# bypass the firewall to ensure VM guest agent and Azure Backup can communicate
# with control plane. These are platform-managed services that do not carry
# customer data.
resource "azurerm_route" "azure_platform" {
  name                   = "azure-platform-services"
  resource_group_name    = azurerm_resource_group.this.name
  route_table_name       = azurerm_route_table.this.name
  address_prefix         = "168.63.129.16/32"
  next_hop_type          = "Internet"
}

# Associate route table with workload subnet
resource "azurerm_subnet_route_table_association" "this" {
  subnet_id      = azurerm_subnet.workload.id
  route_table_id = azurerm_route_table.this.id
}

# ---------------------------------------------------------------------------
# VNet Peering (Spoke-to-Hub)
# ---------------------------------------------------------------------------
# ARCHITECTURE DECISION: Spoke-to-hub peering allows workloads in the spoke
# to reach hub services (Azure DNS, management endpoints, Bastion).
# The reverse peering (hub-to-spoke) is created in the hub-network module
# because the hub resource group is a different management scope.
#
# SECURITY SAFEGUARD: Gateway transit is NOT enabled on the spoke side. This
# prevents the spoke VNet from using the hub VPN/ExpressRoute gateway without
# explicit approval from the platform team.
#
# ARCHITECTURE DECISION: allow_forwarded_traffic is enabled so that traffic
# from the firewall (NVA) can reach spoke workloads. Traffic from the firewall
# has source IP of the firewall itself and is "forwarded" traffic from the
# spoke's perspective.

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                      = "peer-spoke-${var.environment}-to-hub"
  resource_group_name       = azurerm_resource_group.this.name
  virtual_network_name      = azurerm_virtual_network.this.name
  remote_virtual_network_id = var.hub_vnet_id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  # SECURITY SAFEGUARD: Gateway transit must be explicitly approved. Disabled by default.
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

# ---------------------------------------------------------------------------
# Diagnostic Settings
# ---------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "vnet" {
  name                       = "diag-spoke-vnet-to-law"
  target_resource_id         = azurerm_virtual_network.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "VMProtectionAlerts"
  }
  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

resource "azurerm_monitor_diagnostic_setting" "nsg_flow" {
  name                       = "diag-spoke-nsg-flow-to-law"
  target_resource_id         = azurerm_network_security_group.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "NetworkSecurityGroupFlowEvent"
    retention_policy {
      enabled = false
      days    = 0
    }
  }
  enabled_log {
    category = "NetworkSecurityGroupRuleCounter"
    retention_policy {
      enabled = false
      days    = 0
    }
  }
}

# ---------------------------------------------------------------------------
# Network Security Group
# ---------------------------------------------------------------------------
# ARCHITECTURE DECISION: NSG on the workload subnet provides defence-in-depth
# at the subnet boundary. While forced tunnelling through the firewall covers
# egress, the NSG provides:
# 1. Inbound filtering (what can reach the workload from within the VNet)
# 2. East-west traffic control (between VMs in the same subnet)
# 3. A second layer of defence if the firewall is misconfigured

resource "azurerm_network_security_group" "this" {
  name                = "nsg-spoke-${var.environment}-${var.region}"
  location            = var.region
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags

  # SECURITY SAFEGUARD: Deny all inbound by default. Only explicitly allow
  # traffic from the hub (management) and Azure Load Balancer health probes.
  security_rule {
    name                       = "AllowAzureLoadBalancer"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "this" {
  subnet_id                 = azurerm_subnet.workload.id
  network_security_group_id = azurerm_network_security_group.this.id
}
