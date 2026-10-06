# Worker asíncrono con escala a cero — Azure
#
# Container Apps Job disparado por KEDA según el largo de una cola de
# Service Bus Standard, con identidad administrada para la cola, el scaler y
# el storage. Sin connection strings: el namespace no acepta SAS.

resource "azurerm_resource_group" "this" {
  name     = "rg-${var.name}"
  location = var.location
  tags     = var.tags
}

# --- Service Bus --------------------------------------------------------------

resource "azurerm_servicebus_namespace" "this" {
  #checkov:skip=CKV_AZURE_204:Standard no soporta Private Endpoint ni reglas de VNet; requiere Premium (gotcha: sb-private-endpoint-premium).
  #checkov:skip=CKV_AZURE_199:Doble cifrado solo disponible en Premium.
  #checkov:skip=CKV_AZURE_201:CMK solo disponible en Premium.
  #checkov:skip=CKV_AZURE_202:La identidad del namespace solo sirve para CMK (Premium); el acceso usa la identidad del worker.
  name                = var.servicebus_namespace_name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = "Standard"
  local_auth_enabled  = false
  minimum_tls_version = "1.2"
  tags                = var.tags
}

resource "azurerm_servicebus_queue" "jobs" {
  name                                 = "jobs"
  namespace_id                         = azurerm_servicebus_namespace.this.id
  lock_duration                        = "PT1M"
  max_delivery_count                   = var.max_delivery_count
  default_message_ttl                  = "P14D"
  dead_lettering_on_message_expiration = true
}

# --- Storage de resultados ----------------------------------------------------

resource "azurerm_storage_account" "results" {
  #checkov:skip=CKV_AZURE_59:Acceso público de red con auth solo Entra ID: el job de Container Apps sin VNet no tiene IP de salida fija.
  #checkov:skip=CKV_AZURE_35:Ídem: sin VNet no hay subnet ni IP estable para reglas de red.
  #checkov:skip=CKV2_AZURE_33:Private Endpoint fuera de alcance de este patrón (ver private-web-api).
  #checkov:skip=CKV2_AZURE_1:CMK fuera de alcance del patrón.
  #checkov:skip=CKV_AZURE_206:ZRS suficiente para resultados regenerables.
  #checkov:skip=CKV_AZURE_33:No se usa Queue Storage.
  name                              = var.storage_account_name
  resource_group_name               = azurerm_resource_group.this.name
  location                          = azurerm_resource_group.this.location
  account_kind                      = "StorageV2"
  account_tier                      = "Standard"
  account_replication_type          = "ZRS"
  shared_access_key_enabled         = false
  default_to_oauth_authentication   = true
  local_user_enabled                = false
  allow_nested_items_to_be_public   = false
  cross_tenant_replication_enabled  = false
  https_traffic_only_enabled        = true
  min_tls_version                   = "TLS1_2"
  infrastructure_encryption_enabled = true

  blob_properties {
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }

  tags = var.tags
}

resource "azurerm_storage_container" "results" {
  #checkov:skip=CKV2_AZURE_21:Logging de lectura vía diagnostic settings, fuera de alcance del patrón.
  name                  = "results"
  storage_account_id    = azurerm_storage_account.results.id
  container_access_type = "private"
}

# --- Identidad del worker (contenedor + scaler) -------------------------------

resource "azurerm_user_assigned_identity" "worker" {
  name                = "id-${var.name}-worker"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = var.tags
}

# Receiver alcanza para leer, completar y para que KEDA consulte el largo de la cola.
resource "azurerm_role_assignment" "worker_queue" {
  scope                = azurerm_servicebus_queue.jobs.id
  role_definition_name = "Azure Service Bus Data Receiver"
  principal_id         = azurerm_user_assigned_identity.worker.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "worker_results" {
  scope                = azurerm_storage_container.results.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.worker.principal_id
  principal_type       = "ServicePrincipal"
}

# --- Container Apps Job (event-driven) ----------------------------------------

resource "azurerm_container_app_environment" "this" {
  name                = "cae-${var.name}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }

  tags = var.tags
}

resource "azurerm_container_app_job" "worker" {
  name                         = "caj-${var.name}-worker"
  resource_group_name          = azurerm_resource_group.this.name
  location                     = azurerm_resource_group.this.location
  container_app_environment_id = azurerm_container_app_environment.this.id
  workload_profile_name        = "Consumption"
  replica_timeout_in_seconds   = var.replica_timeout_seconds
  replica_retry_limit          = 1

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.worker.id]
  }

  event_trigger_config {
    parallelism              = 1
    replica_completion_count = 1

    scale {
      min_executions              = 0
      max_executions              = var.max_executions
      polling_interval_in_seconds = 30

      rules {
        name             = "servicebus-jobs"
        custom_rule_type = "azure-servicebus"
        # El scaler se autentica con la identidad, no con un connection string
        # (gotcha: keda-scaler-identity).
        identity_id = azurerm_user_assigned_identity.worker.id
        metadata = {
          namespace    = azurerm_servicebus_namespace.this.name
          queueName    = azurerm_servicebus_queue.jobs.name
          messageCount = tostring(var.messages_per_execution)
        }
      }
    }
  }

  template {
    container {
      name   = "worker"
      image  = var.container_image
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "AZURE_CLIENT_ID"
        value = azurerm_user_assigned_identity.worker.client_id
      }
      env {
        name  = "SERVICEBUS_FQDN"
        value = "${azurerm_servicebus_namespace.this.name}.servicebus.windows.net"
      }
      env {
        name  = "SERVICEBUS_QUEUE"
        value = azurerm_servicebus_queue.jobs.name
      }
      env {
        name  = "RESULTS_CONTAINER_URL"
        value = "${azurerm_storage_account.results.primary_blob_endpoint}${azurerm_storage_container.results.name}"
      }
    }
  }

  tags = var.tags

  depends_on = [azurerm_role_assignment.worker_queue, azurerm_role_assignment.worker_results]
}
