# Tests sin credenciales ni recursos reales: mock_provider + command = plan.

mock_provider "azurerm" {}

variables {
  name = "audit-test"
  source_subscription_ids = [
    "00000000-0000-0000-0000-000000000001",
    "00000000-0000-0000-0000-000000000002",
  ]
}

run "one_diagnostic_setting_per_subscription" {
  command = plan

  assert {
    condition     = length(azurerm_monitor_diagnostic_setting.activity_log) == 2
    error_message = "Hace falta un diagnostic setting por suscripción de origen."
  }

  assert {
    condition     = alltrue([for d in azurerm_monitor_diagnostic_setting.activity_log : startswith(d.target_resource_id, "/subscriptions/")])
    error_message = "El diagnostic setting del Activity Log apunta a la suscripción, no a un recurso."
  }
}

run "all_activity_log_categories_are_exported" {
  command = plan

  assert {
    condition = alltrue([
      for d in azurerm_monitor_diagnostic_setting.activity_log :
      length(d.enabled_log) == 8 && contains([for l in d.enabled_log : l.category], "Administrative") && contains([for l in d.enabled_log : l.category], "Policy")
    ])
    error_message = "Para exportar todos los eventos de la suscripción hay que seleccionar todas las categorías."
  }
}

run "workspace_keeps_the_configured_retention" {
  command = plan

  variables {
    retention_in_days = 730
  }

  assert {
    condition     = azurerm_log_analytics_workspace.audit.retention_in_days == 730
    error_message = "La retención del workspace la define el patrón, no el default del Activity Log."
  }
}

run "workspace_is_locked_by_default" {
  command = plan

  assert {
    condition     = length(azurerm_management_lock.workspace) == 1 && one(azurerm_management_lock.workspace).lock_level == "CanNotDelete"
    error_message = "El workspace de auditoría no se puede borrar por accidente."
  }
}

run "archive_copy_is_optional" {
  command = plan

  assert {
    condition     = alltrue([for d in azurerm_monitor_diagnostic_setting.activity_log : d.storage_account_id == null])
    error_message = "Sin storage_account_id no se archiva una copia."
  }
}

run "archive_copy_goes_to_the_given_storage" {
  command = plan

  variables {
    archive_storage_account_id = "/subscriptions/00000000-0000-0000-0000-000000000009/resourceGroups/rg-archive/providers/Microsoft.Storage/storageAccounts/stauditarchive"
  }

  assert {
    condition     = alltrue([for d in azurerm_monitor_diagnostic_setting.activity_log : endswith(d.storage_account_id, "stauditarchive")])
    error_message = "La copia de archivo va al storage account indicado."
  }
}

run "readers_get_log_analytics_reader" {
  command = plan

  variables {
    reader_principal_ids = ["00000000-0000-0000-0000-0000000000aa"]
  }

  assert {
    condition     = alltrue([for r in azurerm_role_assignment.readers : r.role_definition_name == "Log Analytics Reader"])
    error_message = "Los lectores reciben acceso de solo lectura al workspace."
  }
}

run "rejects_a_malformed_subscription_id" {
  command = plan

  variables {
    source_subscription_ids = ["not-a-guid"]
  }

  expect_failures = [var.source_subscription_ids]
}
