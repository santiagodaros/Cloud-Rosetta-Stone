output "hub_network_id" {
  description = "VPC hub (para conectar el Cloud Router híbrido y el DNS compartido)."
  value       = google_compute_network.this["hub"].id
}

output "spoke_network_ids" {
  description = "VPC de los spokes, por nombre."
  value       = { for k in keys(var.spokes) : k => google_compute_network.this[k].id }
}

output "firewall_endpoint_ids" {
  description = "Firewall endpoints, por zona."
  value       = { for k, v in google_network_security_firewall_endpoint.this : k => v.id }
}
