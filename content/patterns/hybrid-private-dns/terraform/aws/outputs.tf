output "inbound_endpoint_ips" {
  description = "IPs para los forwarders condicionales on-premises (se conocen después del apply)."
  value       = [for ip in aws_route53_resolver_endpoint.inbound.ip_address : ip.ip]
}

output "resolver_rule_id" {
  description = "Regla de reenvío, para compartir con AWS RAM a otras cuentas."
  value       = aws_route53_resolver_rule.onprem.id
}
