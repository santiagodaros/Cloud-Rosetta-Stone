# Logs de auditoría centralizados — AWS
#
# Un trail de organización (se crea en la cuenta de management) entrega los eventos de todas las
# cuentas a un bucket S3 cifrado con una clave KMS, en una cuenta de log archive aparte. El
# bucket y la clave llevan las políticas que CloudTrail exige: si están mal, el trail se crea igual.
# Nota: el ejemplo oficial de bucket policy es de un bucket de la cuenta de management; el bucket
# en otra cuenta (log archive) conviene probarlo en un entorno de prueba antes de usarlo.

data "aws_caller_identity" "archive" {}

locals {
  bucket_name = "${var.name}-cloudtrail-${data.aws_caller_identity.archive.account_id}"
  bucket_arn  = "arn:aws:s3:::${local.bucket_name}"

  # El ARN del trail se arma a mano para no crear un ciclo con las políticas que lo preceden.
  trail_arn = "arn:aws:cloudtrail:${var.region}:${var.management_account_id}:trail/${var.trail_name}"

  # Statements de lectura solo si hay lectores: por defecto nadie fuera de management lee los logs
  # (gotcha: org-bucket-policy-needs-org-statement).
  reader_bucket_statements = length(var.reader_role_arns) == 0 ? [] : [
    {
      Sid       = "AllowAuditReaders"
      Effect    = "Allow"
      Principal = { AWS = var.reader_role_arns }
      Action    = ["s3:GetObject", "s3:ListBucket"]
      Resource  = [local.bucket_arn, "${local.bucket_arn}/*"]
    }
  ]

  reader_key_statements = length(var.reader_role_arns) == 0 ? [] : [
    {
      Sid       = "EnableCloudTrailLogDecryptPermissions"
      Effect    = "Allow"
      Principal = { AWS = var.reader_role_arns }
      Action    = "kms:Decrypt"
      Resource  = "*"
      Condition = { Null = { "kms:EncryptionContext:aws:cloudtrail:arn" = "false" } }
    }
  ]
}

# --- Clave KMS ---------------------------------------------------------------------

# Sin estas sentencias, o con la clave deshabilitada, CloudTrail no puede entregar los logs, y
# el trail de organización se crea igual (gotcha: kms-decrypt-before-enabling).
resource "aws_kms_key" "logs" {
  description             = "${var.name}: cifrado de los logs del trail de organización"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Sid       = "EnableAccountAdministration"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.archive.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "AllowCloudTrailEncryptLogs"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "kms:GenerateDataKey*"
        Resource  = "*"
        Condition = {
          StringEquals = { "aws:SourceArn" = local.trail_arn }
          StringLike   = { "kms:EncryptionContext:aws:cloudtrail:arn" = "arn:aws:cloudtrail:*:${var.management_account_id}:trail/*" }
        }
      },
      {
        Sid       = "AllowCloudTrailDecryptTrail"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "kms:Decrypt"
        Resource  = "*"
      },
      {
        Sid       = "AllowCloudTrailDescribeKey"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "kms:DescribeKey"
        Resource  = "*"
        Condition = { StringEquals = { "aws:SourceArn" = local.trail_arn } }
      },
    ], local.reader_key_statements)
  })
}

resource "aws_kms_alias" "logs" {
  name          = "alias/${var.name}-cloudtrail"
  target_key_id = aws_kms_key.logs.key_id
}

# --- Bucket central ----------------------------------------------------------------

resource "aws_s3_bucket" "logs" {
  #checkov:skip=CKV_AWS_144:la réplica cross-region exige un segundo bucket y un rol de replicación que dependen de la política de DR de cada organización; se suma con aws_s3_bucket_replication_configuration
  #checkov:skip=CKV_AWS_18:el access logging exigiría otro bucket de destino; si se necesita ese registro, usar data events de CloudTrail sobre este bucket
  #checkov:skip=CKV2_AWS_62:las notificaciones de eventos del bucket están fuera del alcance del patrón

  bucket = local.bucket_name
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    bucket_key_enabled = true

    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.logs.arn
    }
  }
}

# La retención la define el ciclo de vida del bucket: expira los objetos a los N días.
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "expire-audit-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = var.log_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = var.log_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.logs]
}

# Tres sentencias para el trail de organización: la ACL del bucket, el prefijo de la cuenta de
# management y el prefijo de la organización, con aws:SourceArn del trail de la cuenta de
# management (gotcha: org-bucket-policy-needs-org-statement).
resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = local.bucket_arn
        Condition = { StringEquals = { "aws:SourceArn" = local.trail_arn } }
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${local.bucket_arn}/AWSLogs/${var.management_account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"  = "bucket-owner-full-control"
            "aws:SourceArn" = local.trail_arn
          }
        }
      },
      {
        Sid       = "AWSCloudTrailOrganizationWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${local.bucket_arn}/AWSLogs/${var.organization_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"  = "bucket-owner-full-control"
            "aws:SourceArn" = local.trail_arn
          }
        }
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [local.bucket_arn, "${local.bucket_arn}/*"]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      },
    ], local.reader_bucket_statements)
  })

  depends_on = [aws_s3_bucket_public_access_block.logs]
}

# --- Trail de organización (cuenta de management) ----------------------------------

# Multi-región y de organización: registra la cuenta de management y todas las miembro. La
# validación de integridad entrega archivos digest pero no valida nada por sí sola
# (gotcha: log-file-validation-is-not-automatic).
resource "aws_cloudtrail" "organization" {
  provider = aws.management

  #checkov:skip=CKV_AWS_252:el trail entrega a S3; las notificaciones SNS son opcionales y no forman parte de este patrón
  #checkov:skip=CKV2_AWS_10:la integración con CloudWatch Logs exige un rol y un log group de la propia cuenta del trail (no sirven los de otra cuenta) y el patrón entrega solo a la cuenta de log archive

  name                          = var.trail_name
  s3_bucket_name                = aws_s3_bucket.logs.id
  kms_key_id                    = aws_kms_key.logs.arn
  is_organization_trail         = true
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true

  depends_on = [aws_s3_bucket_policy.logs, aws_kms_key.logs]
}
