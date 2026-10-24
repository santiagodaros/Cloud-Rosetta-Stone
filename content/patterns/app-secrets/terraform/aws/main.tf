# Secretos de aplicación — AWS
#
# Secrets Manager con clave KMS propia, leído con un rol IAM por un interface VPC endpoint, y con la política del
# secreto exigiendo ese endpoint.
#
# El módulo NO crea el valor del secreto: un aws_secretsmanager_secret_version dejaría el valor en el state de
# Terraform. Cargalo fuera de banda (aws secretsmanager put-secret-value) desde la VPC.
#
# La auditoría de accesos sale de CloudTrail, que se configura a nivel de cuenta y queda fuera de este módulo.

data "aws_caller_identity" "current" {}

# --- Clave KMS -------------------------------------------------------------------

resource "aws_kms_key" "secrets" {
  description             = "Cifra los secretos de ${var.name}"
  enable_key_rotation     = true
  deletion_window_in_days = var.kms_deletion_window_in_days

  # Con una CMK el acceso lo definís vos; el rol del workload recibe kms:Decrypt en su propia política
  # (gotcha: cmk-needs-kms-permission). Esta key policy delega la administración en IAM de la cuenta.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnableIAMPolicies"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/${var.name}-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

# --- Secreto ---------------------------------------------------------------------

resource "aws_secretsmanager_secret" "this" {
  name = "${var.name}/app-secret"

  # Nombre y descripción no se cifran: nada sensible acá (gotcha: metadata-not-encrypted).
  description = "Credencial de un tercero consumida por ${var.name}"

  kms_key_id              = aws_kms_key.secrets.arn
  recovery_window_in_days = var.recovery_window_in_days
}

# La política del secreto exige el endpoint VPC para leer el valor (gotcha: vpce-condition-denies-others).
resource "aws_secretsmanager_secret_policy" "this" {
  secret_arn          = aws_secretsmanager_secret.this.arn
  block_public_policy = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "RequireVpcEndpointForSecretValue"
        Effect    = "Deny"
        Principal = "*"
        Action    = "secretsmanager:GetSecretValue"
        Resource  = "*"
        Condition = {
          StringNotEquals = { "aws:sourceVpce" = aws_vpc_endpoint.secretsmanager.id }
        }
      }
    ]
  })
}

resource "aws_secretsmanager_secret_rotation" "this" {
  count = var.rotation_lambda_arn == null ? 0 : 1

  secret_id           = aws_secretsmanager_secret.this.id
  rotation_lambda_arn = var.rotation_lambda_arn
  rotate_immediately  = false

  rotation_rules {
    automatically_after_days = var.rotation_days
  }
}

# --- Identidad del workload ------------------------------------------------------

resource "aws_iam_role" "workload" {
  name = "${var.name}-workload"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = var.workload_service_principal }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

# Solo este secreto y solo la clave que lo cifra, y solo a través de Secrets Manager
# (gotcha: cmk-needs-kms-permission).
resource "aws_iam_role_policy" "read_secret" {
  name = "read-app-secret"
  role = aws_iam_role.workload.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = aws_secretsmanager_secret.this.arn
      },
      {
        Effect   = "Allow"
        Action   = "kms:Decrypt"
        Resource = aws_kms_key.secrets.arn
        Condition = {
          StringEquals = { "kms:ViaService" = "secretsmanager.${var.region}.amazonaws.com" }
        }
      }
    ]
  })
}

# --- Acceso privado --------------------------------------------------------------

resource "aws_security_group" "endpoint" {
  name        = "${var.name}-secretsmanager-endpoint"
  description = "HTTPS hacia el interface endpoint de Secrets Manager"
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "https_from_workload" {
  for_each = toset(var.workload_cidrs)

  security_group_id = aws_security_group.endpoint.id
  description       = "HTTPS desde el workload"
  cidr_ipv4         = each.value
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

locals {
  endpoint_statements = concat(
    [
      {
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.workload.arn }
        Action    = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource  = aws_secretsmanager_secret.this.arn
      }
    ],
    var.rotation_lambda_role_arn == null ? [] : [
      {
        Effect    = "Allow"
        Principal = { AWS = var.rotation_lambda_role_arn }
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecretVersionStage"
        ]
        Resource = aws_secretsmanager_secret.this.arn
      }
    ]
  )
}

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.endpoint_subnet_ids
  security_group_ids  = [aws_security_group.endpoint.id]
  private_dns_enabled = true

  # La política por default da acceso total a Secrets Manager por el endpoint (gotcha: endpoint-default-policy-allows-all).
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = local.endpoint_statements
  })
}
