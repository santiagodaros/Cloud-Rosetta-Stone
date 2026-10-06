# Tests sin credenciales ni recursos reales: mock_provider + command = plan.

mock_provider "aws" {}

variables {
  name        = "ingest-test"
  bucket_name = "ingest-test-bucket-001"
}

run "lifecycle_uses_ttl_and_prefix" {
  command = plan

  variables {
    ttl_days      = 3
    object_prefix = "incoming/"
  }

  assert {
    condition     = one([for r in aws_s3_bucket_lifecycle_configuration.ingest.rule : r.expiration[0].days if r.id == "expire-incoming"]) == 3
    error_message = "La regla de expiración no usa ttl_days."
  }

  assert {
    condition     = one([for r in aws_s3_bucket_lifecycle_configuration.ingest.rule : r.filter[0].prefix if r.id == "expire-incoming"]) == "incoming/"
    error_message = "El filtro tiene que usar object_prefix sin el nombre del bucket."
  }

  assert {
    condition     = one([for r in aws_s3_bucket_lifecycle_configuration.ingest.rule : r.abort_incomplete_multipart_upload[0].days_after_initiation if r.id == "abort-incomplete-multipart"]) == 1
    error_message = "Falta la regla AbortIncompleteMultipartUpload."
  }
}

run "bucket_is_private" {
  command = plan

  assert {
    condition = alltrue([
      aws_s3_bucket_public_access_block.ingest.block_public_acls,
      aws_s3_bucket_public_access_block.ingest.block_public_policy,
      aws_s3_bucket_public_access_block.ingest.ignore_public_acls,
      aws_s3_bucket_public_access_block.ingest.restrict_public_buckets,
    ])
    error_message = "Block Public Access tiene que estar completo."
  }

  assert {
    condition     = aws_s3_bucket_ownership_controls.ingest.rule[0].object_ownership == "BucketOwnerEnforced"
    error_message = "Las ACLs tienen que estar deshabilitadas (BucketOwnerEnforced)."
  }

  assert {
    condition     = aws_vpc_endpoint.s3.vpc_endpoint_type == "Gateway"
    error_message = "Para S3 en la misma región, el endpoint tiene que ser Gateway (sin costo)."
  }
}

run "break_glass_principals_are_excluded" {
  command = plan

  variables {
    break_glass_principal_arns = ["arn:aws:iam::123456789012:role/admin"]
  }

  assert {
    condition     = contains(keys(local.vpce_deny_condition), "ArnNotLike")
    error_message = "Los principals de break-glass tienen que quedar excluidos del Deny."
  }
}

run "no_break_glass_means_no_exclusion" {
  command = plan

  assert {
    condition     = !contains(keys(local.vpce_deny_condition), "ArnNotLike")
    error_message = "Sin break-glass no debería existir la condición ArnNotLike."
  }
}

run "rejects_zero_ttl" {
  command = plan

  variables {
    ttl_days = 0
  }

  expect_failures = [var.ttl_days]
}
