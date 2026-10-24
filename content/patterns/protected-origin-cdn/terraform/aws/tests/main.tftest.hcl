# Tests sin credenciales ni recursos reales: mock_provider + command = plan.

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_cloudfront_cache_policy" {
    defaults = {
      id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    }
  }

  # El provider valida que la policy sea JSON: el mock por defecto devuelve texto arbitrario.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  name = "assets-test"
}

run "origin_bucket_is_not_public" {
  command = plan

  assert {
    condition = alltrue([
      aws_s3_bucket_public_access_block.origin.block_public_acls,
      aws_s3_bucket_public_access_block.origin.block_public_policy,
      aws_s3_bucket_public_access_block.origin.ignore_public_acls,
      aws_s3_bucket_public_access_block.origin.restrict_public_buckets,
    ])
    error_message = "El bucket de origen no puede tener acceso público: solo CloudFront lo lee."
  }

  assert {
    condition     = aws_s3_bucket_ownership_controls.origin.rule[0].object_ownership == "BucketOwnerEnforced"
    error_message = "Con OAC el Object Ownership tiene que ser Bucket owner enforced (o preferred)."
  }
}

run "oac_always_signs_requests" {
  command = plan

  assert {
    condition = (
      aws_cloudfront_origin_access_control.this.signing_behavior == "always" &&
      aws_cloudfront_origin_access_control.this.origin_access_control_origin_type == "s3" &&
      aws_cloudfront_origin_access_control.this.signing_protocol == "sigv4"
    )
    error_message = "El OAC tiene que firmar siempre los pedidos al origen (signing_behavior = always)."
  }
}

run "origin_is_regular_bucket_not_website_endpoint" {
  command = plan

  assert {
    condition     = length(one(aws_cloudfront_distribution.this.origin).custom_origin_config) == 0
    error_message = "Un website endpoint se configura como custom origin y no admite OAC: el origen tiene que ser el bucket regular."
  }
}

run "viewers_are_redirected_to_https" {
  command = plan

  assert {
    condition     = aws_cloudfront_distribution.this.default_cache_behavior[0].viewer_protocol_policy == "redirect-to-https"
    error_message = "Los visitantes se redirigen a HTTPS."
  }

  assert {
    condition     = toset(aws_cloudfront_distribution.this.default_cache_behavior[0].allowed_methods) == toset(["GET", "HEAD"])
    error_message = "El origen es de solo lectura: la distribución no reenvía métodos de escritura."
  }
}

run "aliases_require_certificate" {
  command = plan

  variables {
    aliases = ["cdn.example.com"]
  }

  expect_failures = [var.aliases]
}
