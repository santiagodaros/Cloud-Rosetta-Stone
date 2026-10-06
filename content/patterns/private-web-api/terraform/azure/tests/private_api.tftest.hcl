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
  name                 = "api-test"
  postgres_server_name = "pg-api-test-001"
  entra_admin = {
    object_id      = "00000000-0000-0000-0000-000000000003"
    principal_name = "pg-admins"
    principal_type = "Group"
  }
}

run "nothing_is_public" {
  command = plan

  assert {
    condition     = azurerm_container_app_environment.this.internal_load_balancer_enabled
    error_message = "El environment tiene que ser interno (ILB)."
  }

  assert {
    condition     = azurerm_postgresql_flexible_server.this.public_network_access_enabled == false
    error_message = "PostgreSQL no puede tener acceso público."
  }

  assert {
    condition     = azurerm_private_endpoint.postgres.private_service_connection[0].subresource_names == tolist(["postgresqlServer"])
    error_message = "El Private Endpoint tiene que apuntar a postgresqlServer."
  }
}

run "postgres_is_passwordless" {
  command = plan

  assert {
    condition = (
      azurerm_postgresql_flexible_server.this.authentication[0].password_auth_enabled == false &&
      azurerm_postgresql_flexible_server.this.authentication[0].active_directory_auth_enabled
    )
    error_message = "PostgreSQL tiene que aceptar solo Entra ID."
  }
}

run "aca_subnet_is_delegated" {
  command = plan

  assert {
    condition     = azurerm_subnet.aca.delegation[0].service_delegation[0].name == "Microsoft.App/environments"
    error_message = "La subnet de workload profiles tiene que estar delegada a Microsoft.App/environments."
  }

  assert {
    condition     = toset(keys(azurerm_private_dns_a_record.aca)) == toset(["*", "@"])
    error_message = "La zona del environment interno necesita los registros * y @."
  }
}

run "app_uses_identity_and_scales_to_zero" {
  command = plan

  assert {
    condition     = azurerm_container_app.api.identity[0].type == "UserAssigned"
    error_message = "La API tiene que usar la identidad administrada."
  }

  assert {
    condition     = azurerm_container_app.api.template[0].min_replicas == 0
    error_message = "La API debería escalar a cero."
  }

  assert {
    condition     = !contains([for e in azurerm_container_app.api.template[0].container[0].env : e.name], "PGPASSWORD")
    error_message = "No puede haber PGPASSWORD en el contenedor."
  }
}

run "rejects_invalid_admin_type" {
  command = plan

  variables {
    entra_admin = {
      object_id      = "00000000-0000-0000-0000-000000000003"
      principal_name = "x"
      principal_type = "Robot"
    }
  }

  expect_failures = [var.entra_admin]
}
