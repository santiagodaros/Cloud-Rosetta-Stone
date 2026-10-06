output "workload_identity_provider" {
  description = "workload_identity_provider para google-github-actions/auth (usa el número de proyecto, no el ID)."
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "service_account" {
  description = "service_account para google-github-actions/auth."
  value       = google_service_account.deploy.email
}

output "attribute_condition" {
  description = "Condición CEL que evalúa cada token."
  value       = local.attribute_condition
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
          - uses: google-github-actions/auth@v3
            with:
              workload_identity_provider: ${google_iam_workload_identity_pool_provider.github.name}
              service_account: ${google_service_account.deploy.email}
  YAML
}
