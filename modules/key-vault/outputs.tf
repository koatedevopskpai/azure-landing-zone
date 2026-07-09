output "vault_id" {
  description = "Resource ID of the Key Vault."
  value       = azurerm_key_vault.this.id
}

output "vault_uri" {
  description = "URI of the Key Vault (e.g., https://kv-platform-uksouth.vault.azure.net/)."
  value       = azurerm_key_vault.this.vault_uri
}

output "vault_name" {
  description = "Name of the Key Vault."
  value       = azurerm_key_vault.this.name
}

output "private_endpoint_id" {
  description = "Resource ID of the Key Vault Private Endpoint."
  value       = azurerm_private_endpoint.key_vault.id
}
