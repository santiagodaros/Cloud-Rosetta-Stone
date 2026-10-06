# Tests sin credenciales ni recursos reales: mock_provider + command = plan.

mock_provider "aws" {}

variables {
  name         = "deploy-test"
  github       = { owner = "contoso", repository = "web" }
  environments = ["production", "staging"]
  policy_arns  = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
}

run "trust_requires_audience_and_exact_subjects" {
  command = plan

  assert {
    condition     = local.trust_conditions.StringEquals["token.actions.githubusercontent.com:aud"] == "sts.amazonaws.com"
    error_message = "La trust policy tiene que exigir aud = sts.amazonaws.com."
  }

  assert {
    condition     = jsonencode(local.trust_conditions.StringEquals["token.actions.githubusercontent.com:sub"]) == jsonencode(["repo:contoso/web:environment:production", "repo:contoso/web:environment:staging"])
    error_message = "El sub tiene que ser exacto, uno por environment."
  }

  assert {
    condition     = !contains(keys(local.trust_conditions), "StringLike")
    error_message = "Sin StringLike: los comodines abren la confianza a más ramas o repos."
  }

  assert {
    condition     = length(aws_iam_openid_connect_provider.github) == 1 && aws_iam_openid_connect_provider.github[0].client_id_list == toset(["sts.amazonaws.com"])
    error_message = "El OIDC provider tiene que aceptar el audience de STS."
  }
}

run "immutable_subject_format" {
  command = plan

  variables {
    github = { owner = "contoso", repository = "web", owner_id = 123, repository_id = 456 }
  }

  assert {
    condition     = contains(local.subjects, "repo:contoso@123/web@456:environment:production")
    error_message = "Con IDs, el sub tiene que usar el formato inmutable owner@id/repo@id."
  }
}

run "reuses_existing_provider" {
  command = plan

  variables {
    create_oidc_provider = false
  }

  assert {
    condition     = length(aws_iam_openid_connect_provider.github) == 0 && length(data.aws_iam_openid_connect_provider.github) == 1
    error_message = "Con create_oidc_provider = false se referencia el provider existente."
  }
}

run "rejects_admin_access" {
  command = plan

  variables {
    policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"]
  }

  expect_failures = [var.policy_arns]
}

run "rejects_wildcard_environments" {
  command = plan

  variables {
    environments = ["prod*"]
  }

  expect_failures = [var.environments]
}
