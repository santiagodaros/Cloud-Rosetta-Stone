output "endpoint_host_name" {
  description = "Host del endpoint de Front Door: lo único que sirve el contenido."
  value       = azurerm_cdn_frontdoor_endpoint.this.host_name
}

output "storage_account_id" {
  description = "Storage Account de origen: acá hay que aprobar la conexión privada pendiente de Front Door (Networking > Private endpoint connections)."
  value       = azurerm_storage_account.origin.id
}

output "custom_domain_validation_token" {
  description = "Token TXT (_dnsauth) para validar el dominio propio. Null si no hay dominio propio."
  value       = try(azurerm_cdn_frontdoor_custom_domain.this[0].validation_token, null)
}
