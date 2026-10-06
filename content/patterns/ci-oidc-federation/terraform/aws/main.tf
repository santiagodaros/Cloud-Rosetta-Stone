# Despliegue desde CI sin secretos — AWS
#
# OIDC provider de GitHub (uno por cuenta) y un rol IAM cuya trust policy
# exige el audience de STS y un sub exacto por environment.

locals {
  github_host = "token.actions.githubusercontent.com"
  repo_path   = var.github.owner_id == null ? "${var.github.owner}/${var.github.repository}" : "${var.github.owner}@${var.github.owner_id}/${var.github.repository}@${var.github.repository_id}"

  # Si el job declara `environment:`, el sub es este (y no el de la rama).
  subjects = sort([for env in var.environments : "repo:${local.repo_path}:environment:${env}"])

  provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn

  trust_conditions = {
    StringEquals = {
      "${local.github_host}:aud" = "sts.amazonaws.com"
      "${local.github_host}:sub" = local.subjects
    }
  }
}

# Sin thumbprint_list: para GitHub, IAM valida el certificado contra su librería
# de CAs raíz y no usa el thumbprint (gotcha: thumbprint-not-used).
resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url            = "https://${local.github_host}"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 0 : 1

  url = "https://${local.github_host}"
}

resource "aws_iam_role" "deploy" {
  name                 = var.name
  description          = "GitHub Actions ${local.repo_path} (${join(", ", local.subjects)})"
  max_session_duration = var.max_session_duration

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = local.provider_arn }
      Condition = local.trust_conditions
    }]
  })
}

resource "aws_iam_role_policy_attachment" "deploy" {
  for_each = var.policy_arns

  role       = aws_iam_role.deploy.name
  policy_arn = each.value
}
