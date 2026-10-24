# Tests sin credenciales ni recursos reales: mock_provider + command = plan.

mock_provider "aws" {}

override_data {
  target = data.aws_caller_identity.current
  values = {
    account_id = "123456789012"
  }
}

variables {
  name                = "secrets-test"
  vpc_id              = "vpc-0123456789abcdef0"
  endpoint_subnet_ids = ["subnet-0aaaaaaaaaaaaaaa1", "subnet-0bbbbbbbbbbbbbbb2"]
  workload_cidrs      = ["10.0.0.0/16"]
}

run "secret_uses_the_cmk" {
  command = plan

  assert {
    condition     = aws_kms_key.secrets.enable_key_rotation
    error_message = "La clave KMS tiene que rotar."
  }

  assert {
    condition     = aws_secretsmanager_secret.this.recovery_window_in_days == 30
    error_message = "La ventana de recuperación por default es de 30 días."
  }

  assert {
    condition     = aws_secretsmanager_secret_policy.this.block_public_policy
    error_message = "La política del secreto tiene que bloquear acceso público."
  }
}

run "private_access_through_interface_endpoint" {
  command = plan

  assert {
    condition     = aws_vpc_endpoint.secretsmanager.vpc_endpoint_type == "Interface" && aws_vpc_endpoint.secretsmanager.service_name == "com.amazonaws.us-east-1.secretsmanager"
    error_message = "Tiene que ser un interface endpoint de Secrets Manager en la región."
  }

  assert {
    condition     = aws_vpc_endpoint.secretsmanager.private_dns_enabled
    error_message = "Sin private DNS el SDK sigue resolviendo el endpoint público."
  }

  assert {
    condition     = alltrue([for r in aws_vpc_security_group_ingress_rule.https_from_workload : r.from_port == 443 && r.to_port == 443 && r.ip_protocol == "tcp"])
    error_message = "El security group del endpoint solo acepta HTTPS."
  }
}

run "rotation_is_opt_in" {
  command = plan

  assert {
    condition     = length(aws_secretsmanager_secret_rotation.this) == 0
    error_message = "Sin rotation_lambda_arn no hay rotación."
  }
}

run "rotation_when_lambda_given" {
  command = plan

  variables {
    rotation_lambda_arn      = "arn:aws:lambda:us-east-1:123456789012:function:rotate-app-secret"
    rotation_lambda_role_arn = "arn:aws:iam::123456789012:role/rotate-app-secret"
    rotation_days            = 45
  }

  assert {
    condition     = length(aws_secretsmanager_secret_rotation.this) == 1 && aws_secretsmanager_secret_rotation.this[0].rotation_rules[0].automatically_after_days == 45
    error_message = "Con rotation_lambda_arn tiene que configurarse la rotación."
  }
}

run "rejects_open_cidr" {
  command = plan

  variables {
    workload_cidrs = ["0.0.0.0/0"]
  }

  expect_failures = [var.workload_cidrs]
}

run "rejects_bad_recovery_window" {
  command = plan

  variables {
    recovery_window_in_days = 3
  }

  expect_failures = [var.recovery_window_in_days]
}
