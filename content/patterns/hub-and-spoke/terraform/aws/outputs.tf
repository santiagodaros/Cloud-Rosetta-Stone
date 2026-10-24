output "transit_gateway_id" {
  description = "Transit Gateway: lo comparten los spokes (con AWS RAM si están en otras cuentas)."
  value       = aws_ec2_transit_gateway.this.id
}

output "inspection_vpc_id" {
  description = "VPC de inspección, para sumar la salida a internet o el attachment híbrido."
  value       = aws_vpc.inspection.id
}

output "spokes_route_table_id" {
  description = "Route table del Transit Gateway asociada a los spokes."
  value       = aws_ec2_transit_gateway_route_table.spokes.id
}

output "inspection_route_table_id" {
  description = "Route table del Transit Gateway asociada al attachment de inspección."
  value       = aws_ec2_transit_gateway_route_table.inspection.id
}
