# =============================================================================
# Private DNS Zones Module - Private Link Resolution
# =============================================================================
# ARCHITECTURE DECISION: Private DNS Zones are used to resolve Private Endpoint
# FQDNs to private IP addresses within the hub-spoke topology. Each Azure PaaS
# service has a dedicated Private DNS Zone (e.g., privatelink.blob.core.windows.net).
#
# Why Private DNS Zones over Azure Private DNS Resolver:
# 1. Private DNS Zones are integrated with Private Endpoints - Azure creates A
#    records automatically when a Private Endpoint is provisioned
# 2. No custom DNS server management - the Azure DNS infrastructure handles resolution
# 3. VNet links allow conditional resolution - the zone resolves only in linked VNets
# 4. Cost: Private DNS Zones are free for DNS queries; resolver requires forwarding
#    rules and is more complex for a single-region deployment
#
# SECURITY SAFEGUARD: The hub VNet is linked as the "resolution hub". All spoke
# VNets are linked with "registration" disabled (they register in the hub-linked
# zones). This prevents namespace pollution where a dev workload could register
# a record that impacts prod resolution.

# ---------------------------------------------------------------------------
# Private DNS Zones
# ---------------------------------------------------------------------------
resource "azurerm_private_dns_zone" "this" {
  for_each = toset(var.private_dns_zones)

  name                = each.key
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# VNet Links - Hub
# ---------------------------------------------------------------------------
# ARCHITECTURE DECISION: The hub VNet gets an "auto-registration" link. This
# means Private Endpoints deployed in the hub (e.g., Key Vault PE) automatically
# register their A records in the Private DNS Zone.
resource "azurerm_private_dns_zone_virtual_network_link" "hub" {
  for_each = azurerm_private_dns_zone.this

  name                  = each.value.name
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = each.value.name
  virtual_network_id    = var.hub_vnet_id
  registration_enabled  = true
  tags                  = var.tags
}

# ---------------------------------------------------------------------------
# VNet Links - Spokes
# ---------------------------------------------------------------------------
# ARCHITECTURE DECISION: Spoke VNets get "resolution-only" links (no auto-reg).
# This ensures spoke-deployed Private Endpoints still get DNS resolution via
# the hub (which has registration enabled). Spoke worklaod VMs query Azure
# DNS, which resolves via the hub-linked zones.
resource "azurerm_private_dns_zone_virtual_network_link" "spokes" {
  for_each = local.spoke_links

  name                  = each.value.zone_name
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = each.value.zone_name
  virtual_network_id    = each.value.spoke_vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

locals {
  # Flatten the spoke links: for each zone, create a link to each spoke VNet
  spoke_links = flatten([
    for zone_key, zone in azurerm_private_dns_zone.this : [
      for spoke_key, spoke_vnet_id in var.spoke_vnet_ids : {
        key            = "${zone_key}-${spoke_key}"
        zone_name      = zone.name
        zone_id        = zone.id
        spoke_key      = spoke_key
        spoke_vnet_id  = spoke_vnet_id
      }
    ]
  ])
  spoke_links_map = {
    for link in local.spoke_links : link.key => link
  }
}
