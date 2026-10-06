# Tests sin credenciales ni recursos reales: mock_provider + command = plan.

mock_provider "azurerm" {}

variables {
  name                      = "worker-test"
  servicebus_namespace_name = "sb-worker-test-001"
  storage_account_name      = "stworkertest001"
}

run "no_keys_anywhere" {
  command = plan

  assert {
    condition     = azurerm_servicebus_namespace.this.local_auth_enabled == false
    error_message = "Service Bus no puede aceptar SAS / connection strings."
  }

  assert {
    condition     = azurerm_storage_account.results.shared_access_key_enabled == false
    error_message = "El storage no puede aceptar Shared Key."
  }

  assert {
    condition     = length(azurerm_container_app_job.worker.event_trigger_config[0].scale[0].rules[0].authentication) == 0
    error_message = "El scaler no debe usar secretos."
  }
}

run "scales_to_zero_on_queue_length" {
  command = plan

  variables {
    messages_per_execution = 20
  }

  assert {
    condition     = azurerm_container_app_job.worker.event_trigger_config[0].scale[0].min_executions == 0
    error_message = "El job tiene que escalar a cero."
  }

  assert {
    condition     = azurerm_container_app_job.worker.event_trigger_config[0].scale[0].rules[0].custom_rule_type == "azure-servicebus"
    error_message = "El scaler tiene que ser azure-servicebus."
  }

  assert {
    condition     = azurerm_container_app_job.worker.event_trigger_config[0].scale[0].rules[0].metadata["messageCount"] == "20"
    error_message = "messageCount tiene que salir de messages_per_execution."
  }
}

run "dead_letter_configured" {
  command = plan

  variables {
    max_delivery_count = 3
  }

  assert {
    condition     = azurerm_servicebus_queue.jobs.max_delivery_count == 3
    error_message = "max_delivery_count no se aplica."
  }

  assert {
    condition     = azurerm_servicebus_queue.jobs.dead_lettering_on_message_expiration
    error_message = "Los mensajes vencidos también tienen que ir a dead-letter."
  }
}

run "least_privilege_roles" {
  command = plan

  assert {
    condition     = azurerm_role_assignment.worker_queue.role_definition_name == "Azure Service Bus Data Receiver"
    error_message = "El worker solo necesita recibir mensajes."
  }
}
