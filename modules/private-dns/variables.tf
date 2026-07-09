variable "private_dns_zones" {
  description = "List of Private DNS Zone names to create (e.g., privatelink.blob.core.windows.net)."
  type        = set(string)
}

variable "hub_vnet_id" {
  description = "Resource ID of the hub VNet."
  type        = string
}

variable "spoke_vnet_ids" {
  description = "Map of spoke VNet IDs keyed by environment."
  type        = map(string)
}

variable "resource_group_name" {
  description = "Name of the resource group for Private DNS Zones."
  type        = string
}

variable "tags" {
  description = "Tags to apply to Private DNS Zones."
  type        = map(string)
}
