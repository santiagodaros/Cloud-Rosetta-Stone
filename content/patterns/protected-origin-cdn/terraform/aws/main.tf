# Origen protegido detrás de CDN — AWS
#
# Bucket S3 sin acceso público, cuya policy solo deja leer al servicio CloudFront y solo en nombre de esta
# distribución (origin access control + AWS:SourceArn). Los visitantes llegan por CloudFront.

data "aws_caller_identity" "current" {}

data "aws_cloudfront_cache_policy" "optimized" {
  name = "Managed-CachingOptimized"
}

locals {
  bucket_name = coalesce(var.bucket_name, "${var.name}-origin-${data.aws_caller_identity.current.account_id}")
}

# --- Origen -----------------------------------------------------------------------

# Bucket regular, no un website endpoint: con un website endpoint no se puede usar OAC
# (gotcha: website-endpoint-cannot-use-oac).
resource "aws_s3_bucket" "origin" {
  #checkov:skip=CKV_AWS_18:El bucket destino de los logs de acceso no se crea en este módulo (decisión de cada equipo).
  #checkov:skip=CKV_AWS_144:La replicación entre regiones requiere un bucket destino y un rol que el módulo no crea.
  #checkov:skip=CKV2_AWS_62:Las notificaciones de eventos dependen de un destino (SNS, SQS, Lambda) que el módulo no conoce.
  bucket = local.bucket_name
}

resource "aws_s3_bucket_public_access_block" "origin" {
  bucket                  = aws_s3_bucket.origin.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Con OAC el Object Ownership tiene que ser Bucket owner enforced o preferred.
resource "aws_s3_bucket_ownership_controls" "origin" {
  bucket = aws_s3_bucket.origin.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "origin" {
  bucket = aws_s3_bucket.origin.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Con SSE-KMS la key policy de la CMK tiene que permitir a la distribución
# (gotcha: sse-kms-needs-key-policy).
resource "aws_s3_bucket_server_side_encryption_configuration" "origin" {
  bucket = aws_s3_bucket.origin.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn == null ? "AES256" : "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "origin" {
  bucket = aws_s3_bucket.origin.id

  rule {
    id     = "abort-incomplete-multipart"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# --- Protección del origen: OAC + policy del bucket --------------------------------

resource "aws_cloudfront_origin_access_control" "this" {
  name                              = "${var.name}-oac"
  description                       = "OAC de ${var.name}: CloudFront firma cada pedido al bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Solo el servicio CloudFront, y solo en nombre de esta distribución
# (gotcha: sourcearn-condition-scopes-the-origin).
data "aws_iam_policy_document" "origin" {
  statement {
    sid       = "AllowCloudFrontServicePrincipalReadOnly"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.origin.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.this.arn]
    }
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.origin.arn, "${aws_s3_bucket.origin.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "origin" {
  bucket = aws_s3_bucket.origin.id
  policy = data.aws_iam_policy_document.origin.json

  depends_on = [aws_s3_bucket_public_access_block.origin]
}

# --- CDN ---------------------------------------------------------------------------

resource "aws_cloudfront_distribution" "this" {
  #checkov:skip=CKV_AWS_310:Un solo origen: el failover necesita un segundo origen (otro bucket o región) que el módulo no crea.
  #checkov:skip=CKV_AWS_374:Las restricciones geográficas son una decisión de negocio; el módulo no limita países por defecto.
  #checkov:skip=CKV2_AWS_32:La response headers policy depende del sitio (CSP, CORS); el módulo no impone una.
  #checkov:skip=CKV2_AWS_47:El check inspecciona un web ACL definido en la misma configuración; acá el ACL es externo (web_acl_arn) y lo gestiona quien lo crea.
  enabled             = true
  comment             = "${var.name} (origen protegido)"
  default_root_object = "index.html"
  aliases             = var.aliases
  web_acl_id          = var.web_acl_arn
  http_version        = "http2and3"
  price_class         = "PriceClass_100"

  origin {
    origin_id                = "s3-origin"
    domain_name              = aws_s3_bucket.origin.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = data.aws_cloudfront_cache_policy.optimized.id
    compress               = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.acm_certificate_arn == null ? true : null
    acm_certificate_arn            = var.acm_certificate_arn
    ssl_support_method             = var.acm_certificate_arn == null ? null : "sni-only"
    minimum_protocol_version       = var.acm_certificate_arn == null ? null : "TLSv1.2_2021"
  }

  dynamic "logging_config" {
    for_each = var.access_log_bucket_domain == null ? [] : [1]
    content {
      bucket          = var.access_log_bucket_domain
      include_cookies = false
      prefix          = "${var.name}/"
    }
  }
}
