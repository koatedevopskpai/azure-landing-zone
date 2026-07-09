# ARCHITECTURE DECISION: Outputs are designed for composition - the landing zone publishes
# its resource IDs and references so that workload Terraform configs can consume them
# via remote state or terraform_remote_state data sources.

output "mg_group_ids" {
  description = "Map of Management Group display names to their IDs."
  value       = module.management_groups.group_ids
}

output "mg_group_hierarchy" {
  description = "The full Management Group hierarchy as a map."
  value       = module.management_groups.hierarchy
}

output "hub_vnet_id" {
  description = "Resource ID of the hub VNet."
  value       = module.hub_network.vnet_id
}

output "hub_vnet_name" {
  description = "Name of the hub VNet."
  value       = module.hub_network.vnet_name
}

output "spoke_vnet_ids" {
  description = "Map of spoke VNet IDs keyed by environment."
  value       = module.spoke_networks[*].vnet_id
}

output "spoke_vnet_peerings" {
  description = "Map of VNet peering IDs from spokes to hub."
  value = {
    for k, v in module.spoke_networks : k => v.hub_peering_id
  }
}

output "firewall_private_ip" {
  description = "Private IP address of the Azure Firewall for UDR next-hop configuration."
  value       = module.hub_network.firewall_private_ip
}

output "firewall_id" {
  description = "Resource ID of the Azure Firewall."
  value       = module.hub_network.firewall_id
}

output "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics Workspace."
  value       = module.log_analytics.workspace_id
}

output "log_analytics_workspace_key" {
  description = "Primary shared key for the Log Analytics Workspace."
  value       = module.log_analytics.workspace_primary_shared_key
  sensitive   = true
}

output "key_vault_uri" {
  description = "URI of the Key Vault for secret references."
  value       = module.key_vault.vault_uri
}

output "key_vault_id" {
  description = "Resource ID of the Key Vault."
  value       = module.key_vault.vault_id
}

output "private_dns_zone_ids" {
  description = "Map of Private DNS Zone names to their resource IDs."
  value       = module.private_dns.zone_ids
}

output "nat_gateway_public_ip" {
  description = "Public IP address of the NAT Gateway for outbound traffic."
  value       = module.hub_network.nat_gateway_public_ip
}

output "bastion_host_id" {
  description = "Resource ID of the Azure Bastion host."
  value       = module.hub_network.bastion_host_id
}

output "entra_group_ids" {
  description = "Map of Entra ID group names to their object IDs."
  value       = module.entra_id.group_ids
  sensitive   = true
}

output "policy_initiative_ids" {
  description = "Map of Azure Policy initiative definition IDs."
  value       = module.azure_policy.initiative_ids
}

output "subscription_id" {
  description = "The Azure subscription ID used for the landing zone."
  value       = var.subscription_id
}
