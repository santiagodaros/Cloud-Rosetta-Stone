output "bucket_name" {
  description = "Bucket central de los logs de CloudTrail."
  value       = aws_s3_bucket.logs.id
}

output "kms_key_arn" {
  description = "Clave KMS con la que CloudTrail cifra los logs."
  value       = aws_kms_key.logs.arn
}

output "trail_arn" {
  description = "Trail de organización. Revisá su estado de entrega con get-trail-status (gotcha: org-trail-validation-failures-dont-block)."
  value       = aws_cloudtrail.organization.arn
}
