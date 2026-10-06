# Despliegue desde CI sin secretos — Azure
#
# User-assigned managed identity con un federated identity credential por
# environment de GitHub (match exacto de issuer + subject) y un único role
# assignment sobre el resource group destino.

data "azurerm_client_config" "current" {}

locals {
  github_issuer = "https://token.actions.githubusercontent.com"
  # Único audience aceptado por Entra ID para federated identity credentials.
  audience = "api://AzureADTokenExchange"

  repo_path = var.github.owner_id == null ? "${var.github.owner}/${var.github.repository}" : "${var.github.owner}@${var.github.owner_id}/${var.github.repository}@${var.github.repository_id}"

  # Si el job declara `environment:`, el sub es este (y no el de la rama).
  subjects = { for env in var.environments : env => "repo:${local.repo_path}:environment:${env}" }
}

resource "azurerm_resource_group" "identity" {
  name     = "rg-${var.name}-identity"
  location = var.location
  tags     = var.tags
}

resource "azurerm_user_assigned_identity" "deploy" {
  name                = "id-${var.name}"
  resource_group_name = azurerm_resource_group.identity.name
  location            = azurerm_resource_group.identity.location
  tags                = var.tags
}

# azurerm crea las credenciales de una misma identidad en serie (desde 3.40);
# en ARM/Bicep hay que forzarlo (gotcha: fic-concurrent-writes-409).
resource "azurerm_federated_identity_credential" "github" {
  for_each = local.subjects

  name                      = "github-${each.key}"
  user_assigned_identity_id = azurerm_user_assigned_identity.deploy.id
  issuer                    = local.github_issuer
  audience                  = [local.audience]
  subject                   = each.value
}

resource "azurerm_role_assignment" "deploy" {
  scope                = var.target_scope_id
  role_definition_name = var.role_definition_name
  principal_id         = azurerm_user_assigned_identity.deploy.principal_id
  principal_type       = "ServicePrincipal"
  description          = "GitHub Actions ${local.repo_path} (${join(", ", sort(tolist(var.environments)))})"
}
