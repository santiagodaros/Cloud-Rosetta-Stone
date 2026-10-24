output "nat_public_ip_addresses" {
  description = "IPs públicas de salida: las que el tercero tiene que permitir (todas)."
  value       = azurerm_public_ip.nat[*].ip_address
}

output "firewall_private_ip" {
  description = "IP privada del firewall: next hop de las rutas 0.0.0.0/0 de otras subnets de workloads."
  value       = azurerm_firewall.this.ip_configuration[0].private_ip_address
}

output "workload_subnet_id" {
  description = "Subnet privada para los workloads."
  value       = azurerm_subnet.workloads.id
}

output "vnet_id" {
  description = "VNet del patrón."
  value       = azurerm_virtual_network.this.id
}
