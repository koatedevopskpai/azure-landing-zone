variable "environment" {
  description = "Environment name (dev, staging, prod)."
  type        = string
}

variable "spoke_cidr" {
  description = "CIDR block for the spoke VNet."
  type        = string
}

variable "region" {
  description = "Azure region for the spoke network."
  type        = string
}

variable "hub_vnet_id" {
  description = "Resource ID of the hub VNet for peering."
  type        = string
}

variable "firewall_private_ip" {
  description = "Private IP of Azure Firewall for UDR next-hop."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics Workspace for diagnostics."
  type        = string
}

variable "tags" {
  description = "Tags to apply to spoke resources."
  type        = map(string)
}
