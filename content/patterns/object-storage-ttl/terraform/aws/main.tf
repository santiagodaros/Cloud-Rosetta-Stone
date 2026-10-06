# Ingesta privada de objetos con expiración (TTL) — AWS
#
# Bucket S3 privado, cifrado con SSE-KMS, accesible por Gateway Endpoint,
# con escritura acotada a un prefijo y expiración a los N días.

# --- Red ----------------------------------------------------------------------

resource "aws_vpc" "this" {
  #checkov:skip=CKV2_AWS_11:Flow logs fuera de alcance del patrón (se cubren en el patrón de networking base).
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "vpc-${var.name}" }
}

# Sin reglas: nada usa el SG default (CIS 5.4).
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = { Name = "rt-${var.name}-private" }
}

# Gateway endpoint: entrada en la route table, sin costo por hora ni por GB
# (gotcha: gateway-endpoint-scope).
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = { Name = "vpce-${var.name}-s3" }
}

# --- Bucket -------------------------------------------------------------------

resource "aws_s3_bucket" "ingest" {
  #checkov:skip=CKV_AWS_21:Sin versioning a propósito: con versioning, Expiration solo agrega un delete marker (gotcha: versioning-delete-marker).
  #checkov:skip=CKV_AWS_144:Replicación cross-region no aplica a datos efímeros con TTL.
  #checkov:skip=CKV_AWS_18:Access logging fuera de alcance; usar CloudTrail data events si se requiere auditoría.
  #checkov:skip=CKV2_AWS_62:Notificaciones de eventos fuera de alcance del patrón.
  bucket        = var.bucket_name
  force_destroy = false
}

# Default desde abril 2023 en buckets nuevos; se declara para evitar drift
# (gotcha: secure-defaults-since-2023).
resource "aws_s3_bucket_public_access_block" "ingest" {
  bucket                  = aws_s3_bucket.ingest.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "ingest" {
  bucket = aws_s3_bucket.ingest.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ingest" {
  #checkov:skip=CKV2_AWS_67:Clave administrada por AWS (aws/s3): sin rotación manual que gestionar ni costo mensual.
  bucket = aws_s3_bucket.ingest.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    # Bucket Keys: menos llamadas a KMS (que se cobran por request).
    bucket_key_enabled = true
  }
}

# --- Expiración (TTL) ---------------------------------------------------------

resource "aws_s3_bucket_lifecycle_configuration" "ingest" {
  bucket = aws_s3_bucket.ingest.id

  rule {
    id     = "expire-incoming"
    status = "Enabled"

    filter {
      prefix = var.object_prefix
    }

    expiration {
      days = var.ttl_days
    }
  }

  # Las partes huérfanas se cobran y no se listan (gotcha: abort-incomplete-multipart).
  rule {
    id     = "abort-incomplete-multipart"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

# --- Perímetro: solo TLS y solo desde el VPC endpoint -------------------------

locals {
  object_arns = "${aws_s3_bucket.ingest.arn}/*"

  # Excluye principals de break-glass del Deny por endpoint. Si la lista está vacía
  # no se agrega la condición (un ArnNotLike vacío no excluye a nadie).
  vpce_deny_condition = merge(
    { StringNotEquals = { "aws:SourceVpce" = aws_vpc_endpoint.s3.id } },
    length(var.break_glass_principal_arns) > 0 ? { ArnNotLike = { "aws:PrincipalArn" = var.break_glass_principal_arns } } : {},
  )
}

resource "aws_s3_bucket_policy" "ingest" {
  bucket = aws_s3_bucket.ingest.id

  # La public access block tiene que existir antes que la policy.
  depends_on = [aws_s3_bucket_public_access_block.ingest]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [aws_s3_bucket.ingest.arn, local.object_arns]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      },
      {
        # Solo operaciones de objetos: la configuración del bucket sigue siendo
        # gestionable desde fuera de la VPC (gotcha: sourcevpce-lockout).
        Sid       = "DenyObjectAccessOutsideVpce"
        Effect    = "Deny"
        Principal = "*"
        Action    = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource  = local.object_arns
        Condition = local.vpce_deny_condition
      },
    ]
  })
}

# --- Identidad del productor --------------------------------------------------

resource "aws_iam_role" "producer" {
  name = "${var.name}-producer"

  # Ejemplo con ECS: cambiá el principal según dónde corra el workload
  # (ec2.amazonaws.com, lambda.amazonaws.com, o un OIDC provider para EKS).
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "producer_put" {
  name = "put-incoming-objects"
  role = aws_iam_role.producer.id

  # Acotado al prefijo: el equivalente de Azure necesita ABAC (gotcha: rbac-scope-is-container).
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject"]
      Resource = "${aws_s3_bucket.ingest.arn}/${var.object_prefix}*"
    }]
  })
}
