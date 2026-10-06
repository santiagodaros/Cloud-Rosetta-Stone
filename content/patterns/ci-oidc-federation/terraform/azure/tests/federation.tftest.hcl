# Tests sin credenciales ni recursos reales: mock_provider + command = plan.

mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      tenant_id = "00000000-0000-0000-0000-000000000001"
      object_id = "00000000-0000-0000-0000-000000000002"
    }
  }
}

variables {
  name            = "deploy-test"
  github          = { owner = "contoso", repository = "web" }
  environments    = ["production", "staging"]
  target_scope_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-web"
}

run "one_exact_credential_per_environment" {
  command = plan

  assert {
    condition     = length(azurerm_federated_identity_credential.github) == 2
    error_message = "Tiene que haber una credencial por environment."
  }

  assert {
    condition     = azurerm_federated_identity_credential.github["production"].subject == "repo:contoso/web:environment:production"
    error_message = "El subject tiene que usar el formato de environment."
  }

  assert {
    condition     = alltrue([for c in azurerm_federated_identity_credential.github : c.issuer == "https://token.actions.githubusercontent.com" && c.audience == tolist(["api://AzureADTokenExchange"])])
    error_message = "Issuer de GitHub y audience api://AzureADTokenExchange en todas las credenciales."
  }
}

run "immutable_subject_format" {
  command = plan

  variables {
    github = { owner = "contoso", repository = "web", owner_id = 123, repository_id = 456 }
  }

  assert {
    condition     = azurerm_federated_identity_credential.github["production"].subject == "repo:contoso@123/web@456:environment:production"
    error_message = "Con IDs, el subject tiene que usar el formato inmutable owner@id/repo@id."
  }
}

run "role_is_scoped_to_the_resource_group" {
  command = plan

  assert {
    condition     = azurerm_role_assignment.deploy.scope == var.target_scope_id && azurerm_role_assignment.deploy.role_definition_name == "Contributor"
    error_message = "Un único role assignment sobre el resource group destino."
  }
}

run "rejects_subscription_scope" {
  command = plan

  variables {
    target_scope_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
  }

  expect_failures = [var.target_scope_id]
}

run "rejects_more_than_20_environments" {
  command = plan

  variables {
    environments = [for i in range(21) : "env-${i}"]
  }

  expect_failures = [var.environments]
}

run "rejects_owner_role" {
  command = plan

  variables {
    role_definition_name = "Owner"
  }

  expect_failures = [var.role_definition_name]
}
