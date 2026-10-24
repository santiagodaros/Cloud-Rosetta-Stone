# Tests sin credenciales ni recursos reales: mock_provider + command = plan.

mock_provider "azurerm" {}

override_data {
  target = data.azurerm_client_config.current
  values = {
    tenant_id = "00000000-0000-0000-0000-000000000001"
    object_id = "00000000-0000-0000-0000-000000000002"
  }
}

variables {
  name                       = "secrets-test"
  log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-logs/providers/Microsoft.OperationalInsights/workspaces/law-test"
}

run "vault_is_rbac_and_protected" {
  command = plan

  assert {
    condition     = azurerm_key_vault.this.rbac_authorization_enabled && azurerm_key_vault.this.purge_protection_enabled
    error_message = "El vault tiene que usar RBAC y purge protection."
  }

  assert {
    condition     = azurerm_key_vault.this.soft_delete_retention_days == 90
    error_message = "La retención por default es de 90 días."
  }
}

run "vault_is_private_only" {
  command = plan

  assert {
    condition     = azurerm_key_vault.this.public_network_access_enabled == false && azurerm_key_vault.this.network_acls[0].default_action == "Deny"
    error_message = "El vault no puede aceptar tráfico público."
  }

  assert {
    condition     = azurerm_private_endpoint.vault.private_service_connection[0].subresource_names == tolist(["vault"])
    error_message = "El Private Endpoint tiene que apuntar al subrecurso vault."
  }

  assert {
    condition     = azurerm_private_dns_zone.vault.name == "privatelink.vaultcore.azure.net"
    error_message = "La zona privada tiene que llamarse privatelink.vaultcore.azure.net."
  }
}

run "app_only_reads_secrets" {
  command = plan

  assert {
    condition     = azurerm_role_assignment.app_reads_secrets.role_definition_name == "Key Vault Secrets User"
    error_message = "La identidad de la app solo lee secretos (Key Vault Secrets User)."
  }
}

run "audit_logs_are_collected" {
  command = plan

  assert {
    condition     = one(azurerm_monitor_diagnostic_setting.vault_audit.enabled_log).category == "AuditEvent"
    error_message = "Falta la categoría AuditEvent en el diagnostic setting."
  }
}

run "key_is_optional" {
  command = plan

  assert {
    condition     = length(azurerm_key_vault_key.app) == 0
    error_message = "La clave es opcional y viene apagada."
  }
}

run "key_when_requested" {
  command = plan

  variables {
    create_app_key = true
  }

  assert {
    condition     = length(azurerm_key_vault_key.app) == 1
    error_message = "create_app_key = true tiene que crear la clave."
  }
}

run "rejects_bad_retention" {
  command = plan

  variables {
    soft_delete_retention_days = 3
  }

  expect_failures = [var.soft_delete_retention_days]
}
