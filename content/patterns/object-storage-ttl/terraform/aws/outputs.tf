output "bucket_arn" {
  description = "ARN del bucket."
  value       = aws_s3_bucket.ingest.arn
}

output "vpc_endpoint_id" {
  description = "ID del Gateway Endpoint (usado en la condición aws:SourceVpce)."
  value       = aws_vpc_endpoint.s3.id
}

output "producer_role_arn" {
  description = "ARN del rol que tiene que asumir el workload productor."
  value       = aws_iam_role.producer.arn
}
