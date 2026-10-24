output "key_vault_id" {
  description = "ID del vault. Para cargar el secreto, dale a quien lo carga el rol Key Vault Secrets Officer sobre este scope y entrá por la red privada."
  value       = azurerm_key_vault.this.id
}

output "key_vault_uri" {
  description = "URI del vault (la aplicación la resuelve por la zona privada privatelink.vaultcore.azure.net)."
  value       = azurerm_key_vault.this.vault_uri
}

output "workload_identity_id" {
  description = "ID de la user-assigned identity; asignala al workload (Container App, Function, VM)."
  value       = azurerm_user_assigned_identity.app.id
}

output "workload_identity_client_id" {
  description = "Client ID de la identidad, para DefaultAzureCredential cuando el workload tiene más de una."
  value       = azurerm_user_assigned_identity.app.client_id
}
