output "client_id" {
  description = "AZURE_CLIENT_ID para azure/login (no es un secreto)."
  value       = azurerm_user_assigned_identity.deploy.client_id
}

output "tenant_id" {
  description = "AZURE_TENANT_ID para azure/login."
  value       = data.azurerm_client_config.current.tenant_id
}

output "subjects" {
  description = "Subjects exactos que acepta cada credencial. Compará con el sub real del token si el login falla con AADSTS70021."
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
          - uses: azure/login@v2
            with:
              client-id: ${azurerm_user_assigned_identity.deploy.client_id}
              tenant-id: ${data.azurerm_client_config.current.tenant_id}
              subscription-id: <subscription del scope>
  YAML
}
