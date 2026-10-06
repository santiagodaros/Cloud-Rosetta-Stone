# Tests sin credenciales ni recursos reales: mock_provider + command = plan.

mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
}

variables {
  name            = "api-test"
  certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
  container_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/api:1.0.0"
}

run "nothing_is_public" {
  command = plan

  assert {
    condition     = aws_lb.this.internal
    error_message = "El ALB tiene que ser interno."
  }

  assert {
    condition     = aws_db_instance.this.publicly_accessible == false
    error_message = "RDS no puede ser públicamente accesible."
  }

  assert {
    condition     = aws_ecs_service.api.network_configuration[0].assign_public_ip == false
    error_message = "Las tareas no pueden tener IP pública."
  }

  assert {
    condition     = aws_lb_listener.https.protocol == "HTTPS"
    error_message = "El listener tiene que ser HTTPS."
  }
}

run "database_uses_iam_and_managed_master" {
  command = plan

  assert {
    condition     = aws_db_instance.this.iam_database_authentication_enabled
    error_message = "RDS tiene que tener IAM auth habilitada."
  }

  assert {
    condition     = aws_db_instance.this.manage_master_user_password
    error_message = "La contraseña del master la tiene que gestionar Secrets Manager."
  }

  assert {
    condition     = !contains([for e in local.app_environment : e.name], "PGPASSWORD")
    error_message = "No puede haber PGPASSWORD en la definición de la tarea."
  }
}

run "fargate_has_private_endpoints" {
  command = plan

  assert {
    condition     = toset(keys(aws_vpc_endpoint.interface)) == toset(["ecr.api", "ecr.dkr", "logs"])
    error_message = "Fargate sin NAT necesita endpoints de ECR (api, dkr) y Logs."
  }

  assert {
    condition     = aws_vpc_endpoint.s3.vpc_endpoint_type == "Gateway"
    error_message = "ECR guarda las capas en S3: hace falta el gateway endpoint."
  }
}

run "db_only_reachable_from_app" {
  command = plan

  assert {
    condition     = aws_vpc_security_group_ingress_rule.db_from_app.from_port == 5432 && aws_vpc_security_group_ingress_rule.db_from_app.cidr_ipv4 == null
    error_message = "La base solo acepta 5432 desde el security group de la app, no desde un CIDR."
  }
}

run "rejects_single_az" {
  command = plan

  variables {
    availability_zones = ["us-east-1a"]
  }

  expect_failures = [var.availability_zones]
}
