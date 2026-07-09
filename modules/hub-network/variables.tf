variable "hub_vnet_cidr" {
  description = "CIDR block for the hub VNet."
  type        = string
}

variable "hub_subnet_prefixes" {
  description = "Subnet prefixes within the hub VNet."
  type = object({
    azure_firewall = string
    bastion        = string
    gateway        = string
    management     = string
  })
}

variable "region" {
  description = "Azure region for the hub network."
  type        = string
}

variable "firewall_sku" {
  description = "Azure Firewall SKU (Standard or Premium)."
  type        = string
}

variable "firewall_threat_intel_mode" {
  description = "Threat intelligence mode for Azure Firewall."
  type        = string
}

variable "bastion_sku" {
  description = "Azure Bastion SKU."
  type        = string
}

variable "ddos_protection_enabled" {
  description = "Enable DDoS Protection Plan."
  type        = bool
}

variable "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics Workspace for diagnostics."
  type        = string
}

variable "spoke_vnets" {
  description = "Map of spoke VNet information for hub-to-spoke peering."
  type = map(object({
    vnet_id = string
  }))
  default = {}
}

variable "tags" {
  description = "Tags to apply to all hub resources."
  type        = map(string)
}
