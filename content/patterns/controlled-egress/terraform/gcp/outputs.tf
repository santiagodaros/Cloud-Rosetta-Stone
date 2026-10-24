output "nat_ip_addresses" {
  description = "IPs externas de salida: las que el tercero tiene que permitir (todas)."
  value       = google_compute_address.nat[*].address
}

output "firewall_policy_id" {
  description = "Network firewall policy con los FQDN permitidos."
  value       = google_compute_network_firewall_policy.this.id
}

output "nat_name" {
  description = "Nombre del Cloud NAT."
  value       = google_compute_router_nat.this.name
}
