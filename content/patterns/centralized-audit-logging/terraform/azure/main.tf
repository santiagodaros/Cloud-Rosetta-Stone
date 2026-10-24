# Logs de auditoría centralizados — Azure
#
# Un workspace de Log Analytics en la suscripción central recibe el Activity Log de cada
# suscripción de origen mediante un diagnostic setting por suscripción. Opcionalmente archiva
# una copia en un storage account existente.

locals {
  # Todas las categorías del Activity Log: la documentación pide seleccionarlas todas para exportar
  # todos los eventos de la suscripción (gotcha: management-group-setting-misses-subscription-events).
  activity_log_categories = [
    "Administrative",
    "Alert",
    "Autoscale",
    "Policy",
    "Recommendation",
    "ResourceHealth",
    "Security",
    "ServiceHealth",
  ]
}

resource "azurerm_resource_group" "audit" {
  name     = "rg-${var.name}"
  location = var.location
  tags     = var.tags
}

# La retención se define acá: el Activity Log por sí solo se borra a los 90 días
# (gotcha: activity-log-default-retention).
resource "azurerm_log_analytics_workspace" "audit" {
  name                = "log-${var.name}"
  resource_group_name = azurerm_resource_group.audit.name
  location            = azurerm_resource_group.audit.location
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_in_days
  tags                = var.tags
}

resource "azurerm_management_lock" "workspace" {
  count = var.lock_workspace ? 1 : 0

  name       = "no-delete-${var.name}"
  scope      = azurerm_log_analytics_workspace.audit.id
  lock_level = "CanNotDelete"
  notes      = "Workspace de auditoría centralizada."
}

resource "azurerm_role_assignment" "readers" {
  for_each = toset(var.reader_principal_ids)

  scope                = azurerm_log_analytics_workspace.audit.id
  role_definition_name = "Log Analytics Reader"
  principal_id         = each.value
}

# Un diagnostic setting por suscripción: el Activity Log se genera solo, pero exportarlo exige
# este recurso en cada suscripción (gotcha: management-group-setting-misses-subscription-events).
resource "azurerm_monitor_diagnostic_setting" "activity_log" {
  for_each = toset(var.source_subscription_ids)

  name                       = "activity-log-to-${var.name}"
  target_resource_id         = "/subscriptions/${each.value}"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.audit.id
  storage_account_id         = var.archive_storage_account_id

  dynamic "enabled_log" {
    for_each = local.activity_log_categories

    content {
      category = enabled_log.value
    }
  }
}
