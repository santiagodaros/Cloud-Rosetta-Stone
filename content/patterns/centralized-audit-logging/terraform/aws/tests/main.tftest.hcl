# Tests sin credenciales ni recursos reales: mock_provider + command = plan.

mock_provider "aws" {}

mock_provider "aws" {
  alias = "management"
}

variables {
  name                  = "audit-test"
  organization_id       = "o-exampleorg1"
  management_account_id = "111111111111"
}

run "trail_covers_the_whole_organization" {
  command = plan

  assert {
    condition     = aws_cloudtrail.organization.is_organization_trail && aws_cloudtrail.organization.is_multi_region_trail
    error_message = "El trail tiene que ser de organización y multi-región para registrar todas las cuentas y regiones."
  }

  assert {
    condition     = aws_cloudtrail.organization.enable_log_file_validation
    error_message = "Sin validación de integridad no se entregan los archivos digest."
  }
}

run "bucket_policy_has_the_organization_statement" {
  command = plan

  assert {
    condition = anytrue([
      for s in jsondecode(aws_s3_bucket_policy.logs.policy).Statement :
      s.Sid == "AWSCloudTrailOrganizationWrite" && endswith(s.Resource, "/AWSLogs/o-exampleorg1/*")
    ])
    error_message = "Sin la sentencia del prefijo de la organización, CloudTrail no puede escribir los logs de las cuentas miembro."
  }

  assert {
    condition = alltrue([
      for s in jsondecode(aws_s3_bucket_policy.logs.policy).Statement :
      s.Effect == "Deny" || s.Condition.StringEquals["aws:SourceArn"] == "arn:aws:cloudtrail:us-east-1:111111111111:trail/organization-audit"
    ])
    error_message = "Toda sentencia de CloudTrail necesita aws:SourceArn con el trail de la cuenta de management."
  }
}

run "bucket_is_private_encrypted_and_versioned" {
  command = plan

  assert {
    condition     = aws_s3_bucket_public_access_block.logs.block_public_policy && aws_s3_bucket_public_access_block.logs.restrict_public_buckets
    error_message = "El bucket de auditoría no puede ser público."
  }

  assert {
    condition     = one(aws_s3_bucket_server_side_encryption_configuration.logs.rule).apply_server_side_encryption_by_default[0].sse_algorithm == "aws:kms"
    error_message = "Los logs se cifran con la clave KMS del patrón."
  }

  assert {
    condition     = aws_s3_bucket_versioning.logs.versioning_configuration[0].status == "Enabled"
    error_message = "Sin versionado, un objeto sobrescrito se pierde."
  }
}

run "key_policy_lets_cloudtrail_encrypt_and_describe" {
  command = plan

  assert {
    condition = anytrue([
      for s in jsondecode(aws_kms_key.logs.policy).Statement :
      s.Sid == "AllowCloudTrailEncryptLogs" && s.Condition.StringLike["kms:EncryptionContext:aws:cloudtrail:arn"] == "arn:aws:cloudtrail:*:111111111111:trail/*"
    ])
    error_message = "La clave tiene que permitir GenerateDataKey a CloudTrail para la cuenta del trail."
  }

  assert {
    condition     = anytrue([for s in jsondecode(aws_kms_key.logs.policy).Statement : s.Sid == "AllowCloudTrailDescribeKey"])
    error_message = "CloudTrail necesita kms:DescribeKey sobre la clave."
  }

  assert {
    condition     = aws_kms_key.logs.enable_key_rotation
    error_message = "La clave de auditoría rota."
  }
}

run "readers_get_decrypt_only_when_listed" {
  command = plan

  variables {
    reader_role_arns = ["arn:aws:iam::222222222222:role/auditor"]
  }

  assert {
    condition = anytrue([
      for s in jsondecode(aws_kms_key.logs.policy).Statement :
      s.Sid == "EnableCloudTrailLogDecryptPermissions" && s.Action == "kms:Decrypt"
    ])
    error_message = "Un lector sin kms:Decrypt no puede leer los logs cifrados."
  }
}

run "no_readers_by_default" {
  command = plan

  assert {
    condition     = !anytrue([for s in jsondecode(aws_s3_bucket_policy.logs.policy).Statement : s.Sid == "AllowAuditReaders"])
    error_message = "Por defecto, nadie fuera de la cuenta de management lee los logs."
  }
}

run "rejects_a_malformed_organization_id" {
  command = plan

  variables {
    organization_id = "exampleorg"
  }

  expect_failures = [var.organization_id]
}
