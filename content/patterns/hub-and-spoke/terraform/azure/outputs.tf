output "hub_vnet_id" {
  description = "VNet hub (para conectar el gateway híbrido y sumar el DNS compartido)."
  value       = azurerm_virtual_network.hub.id
}

output "firewall_private_ip" {
  description = "IP privada del firewall: next hop de las UDR de los spokes (se conoce después del apply)."
  value       = azurerm_firewall.this.ip_configuration[0].private_ip_address
}

output "firewall_policy_id" {
  description = "Firewall Policy, para agregar rule collection groups."
  value       = azurerm_firewall_policy.this.id
}

output "spoke_vnet_ids" {
  description = "VNets de los spokes, por nombre."
  value       = { for k, v in azurerm_virtual_network.spoke : k => v.id }
}
