variable "enforce_private_endpoints" {
  description = "Enable enforcement of Private Endpoints on PaaS resources."
  type        = bool
}

variable "deny_public_ip_on_nics" {
  description = "Enable denial of Public IP addresses on Network Interfaces."
  type        = bool
}

variable "enforce_cmk" {
  description = "Enable enforcement of Customer-Managed Keys."
  type        = bool
}

variable "enforce_https_storage" {
  description = "Enable enforcement of HTTPS-only storage."
  type        = bool
}

variable "mg_group_ids" {
  description = "Map of Management Group IDs for policy assignment scope."
  type        = map(string)
}
