output "policy_id" {
  description = "ID de la S3 policy."
  value       = aws_organizations_policy.block_public_access.id
}

output "attached_target_ids" {
  description = "Targets (raíz, OUs o cuentas) a los que quedó adjunta."
  value       = sort([for a in aws_organizations_policy_attachment.this : a.target_id])
}
