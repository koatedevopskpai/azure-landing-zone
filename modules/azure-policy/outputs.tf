output "initiative_ids" {
  description = "Map of policy initiative/definition IDs."
  value = {
    enforce_private_endpoints = var.enforce_private_endpoints ? azurerm_policy_definition.enforce_private_endpoints[0].id : null
    deny_public_ip_on_nics    = var.deny_public_ip_on_nics ? azurerm_policy_definition.deny_public_ip_on_nics[0].id : null
    enforce_cmk               = var.enforce_cmk ? azurerm_policy_definition.enforce_cmk[0].id : null
    enforce_https_storage     = var.enforce_https_storage ? azurerm_policy_definition.enforce_https_storage[0].id : null
  }
}

output "assignment_ids" {
  description = "Map of policy assignment IDs."
  value = {
    enforce_private_endpoints = var.enforce_private_endpoints ? azurerm_policy_assignment.enforce_private_endpoints[0].id : null
    deny_public_ip_on_nics    = var.deny_public_ip_on_nics ? azurerm_policy_assignment.deny_public_ip_on_nics[0].id : null
    enforce_cmk               = var.enforce_cmk ? azurerm_policy_assignment.enforce_cmk[0].id : null
    enforce_https_storage     = var.enforce_https_storage ? azurerm_policy_assignment.enforce_https_storage[0].id : null
  }
}
