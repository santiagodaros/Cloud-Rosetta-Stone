output "inbound_endpoint_ip" {
  description = "IP para los forwarders condicionales on-premises (zona privada → esta IP)."
  value       = azurerm_private_dns_resolver_inbound_endpoint.this.ip_configurations[0].private_ip_address
}

output "hub_vnet_id" {
  description = "VNet hub (a peerear con los spokes y conectar a on-premises)."
  value       = azurerm_virtual_network.hub.id
}

output "ruleset_id" {
  description = "Forwarding ruleset para linkear más spokes de la misma región."
  value       = azurerm_private_dns_resolver_dns_forwarding_ruleset.this.id
}
