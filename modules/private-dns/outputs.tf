output "zone_ids" {
  description = "Map of Private DNS Zone names to their resource IDs."
  value = {
    for k, v in azurerm_private_dns_zone.this : k => v.id
  }
}

output "zone_names" {
  description = "List of created Private DNS Zone names."
  value = [for z in azurerm_private_dns_zone.this : z.name]
}

output "hub_link_ids" {
  description = "Map of hub VNet link IDs for each zone."
  value = {
    for k, v in azurerm_private_dns_zone_virtual_network_link.hub : k => v.id
  }
}
