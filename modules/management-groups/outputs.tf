output "group_ids" {
  description = "Map of Management Group display names to their resource IDs."
  value = {
    root          = azurerm_management_group.root.id
    platform      = azurerm_management_group.platform.id
    landing_zones = azurerm_management_group.landing_zones.id
    sandbox       = azurerm_management_group.sandbox.id
    decommissioned = azurerm_management_group.decommissioned.id
  }
}

output "environment_group_ids" {
  description = "Map of environment-level Management Group IDs."
  value = {
    for k, v in azurerm_management_group.environments : k => v.id
  }
}

output "hierarchy" {
  description = "Full Management Group hierarchy as a map."
  value = {
    root         = azurerm_management_group.root.name
    platform     = azurerm_management_group.platform.name
    landing_zones = azurerm_management_group.landing_zones.name
    environments = { for k, v in azurerm_management_group.environments : k => v.name }
    sandbox      = azurerm_management_group.sandbox.name
    decommissioned = azurerm_management_group.decommissioned.name
  }
}
