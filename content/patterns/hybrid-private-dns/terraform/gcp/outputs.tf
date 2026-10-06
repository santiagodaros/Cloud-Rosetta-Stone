output "cloud_dns_source_range" {
  description = "Rango a permitir (UDP y TCP 53) en el firewall on-premises y a rutear de vuelta por la VPN/Interconnect."
  value       = local.cloud_dns_source_range
}

output "inbound_forwarder_hint" {
  description = "Las IPs de entrada se ven después del apply con este comando."
  value       = "gcloud compute addresses list --project ${var.project_id} --filter='purpose = \"DNS_RESOLVER\"'"
}
