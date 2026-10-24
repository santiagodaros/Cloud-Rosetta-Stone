output "distribution_domain_name" {
  description = "Dominio de la distribución: lo único que sirve el contenido."
  value       = aws_cloudfront_distribution.this.domain_name
}

output "distribution_arn" {
  description = "ARN de la distribución, para la key policy de una CMK (SSE-KMS)."
  value       = aws_cloudfront_distribution.this.arn
}

output "origin_bucket_id" {
  description = "Bucket de origen, sin acceso público."
  value       = aws_s3_bucket.origin.id
}
