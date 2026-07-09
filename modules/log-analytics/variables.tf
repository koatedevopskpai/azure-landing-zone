variable "region" {
  description = "Azure region for Log Analytics workspace."
  type        = string
}

variable "retention_days" {
  description = "Data retention in days for the Log Analytics workspace."
  type        = number
}

variable "resource_group_name" {
  description = "Name of the resource group for Log Analytics (overridden if empty)."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to Log Analytics resources."
  type        = map(string)
}
