output "role_arn" {
  description = "role-to-assume para aws-actions/configure-aws-credentials (no es un secreto)."
  value       = aws_iam_role.deploy.arn
}

output "subjects" {
  description = "Valores exactos de sub que acepta la trust policy."
  value       = local.subjects
}

output "workflow_snippet" {
  description = "Fragmento mínimo del workflow."
  value       = <<-YAML
    permissions:
      id-token: write   # sin esto el job no puede pedir el token OIDC
      contents: read
    jobs:
      deploy:
        environment: ${sort(tolist(var.environments))[0]}
        steps:
          - uses: aws-actions/configure-aws-credentials@v4
            with:
              role-to-assume: ${aws_iam_role.deploy.arn}
              aws-region: ${var.region}
  YAML
}
