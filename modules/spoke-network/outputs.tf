output "vnet_id" {
  description = "Resource ID of the spoke VNet."
  value       = azurerm_virtual_network.this.id
}

output "vnet_name" {
  description = "Name of the spoke VNet."
  value       = azurerm_virtual_network.this.name
}

output "resource_group_name" {
  description = "Name of the spoke resource group."
  value       = azurerm_resource_group.this.name
}

output "workload_subnet_id" {
  description = "Resource ID of the workload subnet."
  value       = azurerm_subnet.workload.id
}

output "route_table_id" {
  description = "Resource ID of the spoke route table."
  value       = azurerm_route_table.this.id
}

output "nsg_id" {
  description = "Resource ID of the spoke NSG."
  value       = azurerm_network_security_group.this.id
}
