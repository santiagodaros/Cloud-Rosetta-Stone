output "storage_account_id" {
  description = "ID de la Storage Account."
  value       = azurerm_storage_account.this.id
}

output "ingest_container_url" {
  description = "URL del contenedor de ingesta (resuelve a IP privada desde la VNet)."
  value       = "${azurerm_storage_account.this.primary_blob_endpoint}${azurerm_storage_container.ingest.name}"
}

output "producer_identity_client_id" {
  description = "Client ID de la Managed Identity que tiene que usar el workload productor."
  value       = azurerm_user_assigned_identity.producer.client_id
}
