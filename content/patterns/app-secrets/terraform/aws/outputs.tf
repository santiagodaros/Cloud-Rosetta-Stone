output "secret_arn" {
  description = "ARN del secreto. Cargá el valor fuera de banda (put-secret-value), por el endpoint privado."
  value       = aws_secretsmanager_secret.this.arn
}

output "workload_role_arn" {
  description = "Rol del workload; asignalo al task, función o instance profile."
  value       = aws_iam_role.workload.arn
}

output "kms_key_arn" {
  description = "Clave KMS que cifra el secreto."
  value       = aws_kms_key.secrets.arn
}

output "vpc_endpoint_id" {
  description = "Interface endpoint de Secrets Manager (la política del secreto exige este endpoint)."
  value       = aws_vpc_endpoint.secretsmanager.id
}
