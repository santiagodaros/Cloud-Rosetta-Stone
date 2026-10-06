output "servicebus_fqdn" {
  description = "FQDN del namespace (los productores se autentican con Entra ID)."
  value       = "${azurerm_servicebus_namespace.this.name}.servicebus.windows.net"
}

output "queue_name" {
  description = "Cola de trabajos. La dead-letter es <cola>/$DeadLetterQueue."
  value       = azurerm_servicebus_queue.jobs.name
}

output "worker_identity_client_id" {
  description = "Client ID de la identidad del worker."
  value       = azurerm_user_assigned_identity.worker.client_id
}
