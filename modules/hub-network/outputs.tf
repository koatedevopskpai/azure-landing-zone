output "vnet_id" {
  description = "Resource ID of the hub VNet."
  value       = azurerm_virtual_network.this.id
}

output "vnet_name" {
  description = "Name of the hub VNet."
  value       = azurerm_virtual_network.this.name
}

output "resource_group_name" {
  description = "Name of the hub resource group."
  value       = azurerm_resource_group.this.name
}

output "resource_group_id" {
  description = "Resource ID of the hub resource group."
  value       = azurerm_resource_group.this.id
}

output "firewall_id" {
  description = "Resource ID of the Azure Firewall."
  value       = azurerm_firewall.this.id
}

output "firewall_private_ip" {
  description = "Private IP address of the Azure Firewall for UDR next-hop."
  value       = azurerm_firewall.this.ip_configuration[0].private_ip_address
}

output "firewall_public_ip" {
  description = "Public IP address of the Azure Firewall."
  value       = azurerm_public_ip.firewall.ip_address
}

output "nat_gateway_id" {
  description = "Resource ID of the NAT Gateway."
  value       = azurerm_nat_gateway.this.id
}

output "nat_gateway_public_ip" {
  description = "Public IP address of the NAT Gateway."
  value       = azurerm_public_ip.nat_gateway.ip_address
}

output "bastion_host_id" {
  description = "Resource ID of the Azure Bastion host."
  value       = azurerm_bastion_host.this.id
}

output "bastion_host_dns" {
  description = "FQDN for the Azure Bastion host."
  value       = azurerm_bastion_host.this.dns_name
}

output "firewall_policy_id" {
  description = "Resource ID of the Firewall Policy."
  value       = azurerm_firewall_policy.this.id
}

output "subnet_ids" {
  description = "Map of hub subnet names to IDs."
  value = {
    firewall  = azurerm_subnet.azure_firewall.id
    bastion   = azurerm_subnet.bastion.id
    gateway   = azurerm_subnet.gateway.id
    management = azurerm_subnet.management.id
  }
}
