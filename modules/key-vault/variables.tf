variable "region" {
  description = "Azure region for Key Vault."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group for Key Vault."
  type        = string
}

variable "tenant_id" {
  description = "Azure Entra ID tenant ID."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Resource ID of Log Analytics Workspace for diagnostics."
  type        = string
}

variable "tags" {
  description = "Tags to apply to Key Vault."
  type        = map(string)
}
