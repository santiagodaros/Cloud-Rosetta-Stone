# Tests sin credenciales ni recursos reales: mock_provider + command = plan.

mock_provider "azurerm" {}

variables {
  name                 = "ingest-test"
  storage_account_name = "stingesttest001"
}

run "lifecycle_uses_ttl_and_container_prefix" {
  command = plan

  variables {
    ttl_days      = 3
    object_prefix = "incoming/"
  }

  assert {
    condition     = azurerm_storage_management_policy.ttl.rule[0].actions[0].base_blob[0].delete_after_days_since_creation_greater_than == 3
    error_message = "La regla de lifecycle no usa ttl_days."
  }

  assert {
    condition     = azurerm_storage_management_policy.ttl.rule[0].filters[0].prefix_match == toset(["ingest/incoming/"])
    error_message = "El prefijo tiene que empezar con el nombre del contenedor."
  }
}

run "storage_is_keyless_and_private" {
  command = plan

  assert {
    condition     = azurerm_storage_account.this.shared_access_key_enabled == false
    error_message = "Shared Key tiene que estar deshabilitado."
  }

  assert {
    condition     = azurerm_storage_account.this.public_network_access == "Disabled"
    error_message = "El acceso público de red tiene que estar deshabilitado."
  }

  assert {
    condition     = azurerm_storage_account.this.allow_nested_items_to_be_public == false
    error_message = "No se permiten contenedores públicos."
  }

  assert {
    condition     = azurerm_private_endpoint.blob.private_service_connection[0].subresource_names == tolist(["blob"])
    error_message = "El Private Endpoint tiene que apuntar al subresource blob."
  }
}

run "producer_role_is_data_plane_only" {
  command = plan

  assert {
    condition     = azurerm_role_assignment.producer_blob_writer.role_definition_name == "Storage Blob Data Contributor"
    error_message = "El productor necesita un rol de data plane, no Contributor."
  }
}

run "rejects_zero_ttl" {
  command = plan

  variables {
    ttl_days = 0
  }

  expect_failures = [var.ttl_days]
}
