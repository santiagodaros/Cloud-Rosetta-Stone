output "nat_public_ips" {
  description = "Elastic IPs de salida, por AZ: las que el tercero tiene que permitir (todas)."
  value       = { for az, eip in aws_eip.nat : az => eip.public_ip }
}

output "nat_gateway_ids" {
  description = "NAT gateway de cada AZ."
  value       = { for az, nat in aws_nat_gateway.this : az => nat.id }
}

output "firewall_arn" {
  description = "ARN del firewall de salida."
  value       = aws_networkfirewall_firewall.this.arn
}
