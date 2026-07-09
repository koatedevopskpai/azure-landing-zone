variable "tenant_id" {
  description = "Azure Entra ID tenant ID."
  type        = string
}

variable "subscription_id" {
  description = "Azure subscription ID to associate with Platform MG."
  type        = string
}

variable "root_mg_name" {
  description = "Display name for the root Management Group."
  type        = string
}

variable "environment_mgs" {
  description = "Map of environment names to Management Group display names."
  type        = map(string)
}
