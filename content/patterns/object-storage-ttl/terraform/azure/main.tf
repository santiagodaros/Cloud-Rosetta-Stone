# Ingesta privada de objetos con expiración (TTL) — Azure
#
# Storage Account sin claves (solo Entra ID), sin acceso público de red,
# alcanzable por Private Endpoint, con un contenedor de ingesta cuyo
# contenido se borra a los N días.

resource "azurerm_resource_group" "this" {
  name     = "rg-${var.name}"
  location = var.location
  tags     = var.tags
}

# --- Red ----------------------------------------------------------------------

resource "azurerm_virtual_network" "this" {
  name                = "vnet-${var.name}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  address_space       = [var.vnet_address_space]
  tags                = var.tags
}

resource "azurerm_subnet" "endpoints" {
  name                 = "snet-private-endpoints"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.endpoints_subnet_prefix]
}

# Sin reglas propias: las default permiten tráfico intra-VNet y bloquean internet.
# Para que el NSG filtre tráfico hacia Private Endpoints hay que habilitar
# network policies en la subnet (private_endpoint_network_policies).
resource "azurerm_network_security_group" "endpoints" {
  name                = "nsg-${var.name}-endpoints"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = var.tags
}

resource "azurerm_subnet_network_security_group_association" "endpoints" {
  subnet_id                 = azurerm_subnet.endpoints.id
  network_security_group_id = azurerm_network_security_group.endpoints.id
}

# --- Storage ------------------------------------------------------------------

resource "azurerm_storage_account" "this" {
  #checkov:skip=CKV2_AZURE_1:CMK fuera de alcance del patrón; cifrado con claves de Microsoft + infraestructura.
  #checkov:skip=CKV_AZURE_206:ZRS es suficiente para datos efímeros con TTL; GRS duplica costo sin beneficio.
  #checkov:skip=CKV_AZURE_33:No se usa Queue Storage en este patrón.
  #checkov:skip=CKV_AZURE_59:checkov evalúa public_network_access_enabled (deprecado en azurerm 5); acá se usa public_network_access = "Disabled".
  #checkov:skip=CKV_AZURE_36:Sin bypass de servicios de confianza a propósito: el único camino es el Private Endpoint.
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "ZRS"

  # Identidad: solo Entra ID. Sin Shared Key, sin SAS de cuenta, sin usuarios locales.
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  local_user_enabled              = false

  # Red: sin endpoint público. El único camino es el Private Endpoint.
  public_network_access = "Disabled"

  allow_nested_items_to_be_public   = false
  cross_tenant_replication_enabled  = false
  https_traffic_only_enabled        = true
  min_tls_version                   = "TLS1_2"
  infrastructure_encryption_enabled = true

  network_rules {
    default_action = "Deny"
    bypass         = ["None"]
  }

  blob_properties {
    # Sin versioning: con versiones previas, lifecycle no borra la versión actual
    # hasta borrar las anteriores, y el TTL deja de ser predecible.
    versioning_enabled = false

    delete_retention_policy {
      days = var.soft_delete_retention_days
    }

    container_delete_retention_policy {
      days = 7
    }
  }

  tags = var.tags
}

resource "azurerm_storage_container" "ingest" {
  #checkov:skip=CKV2_AZURE_21:Logging de lectura vía diagnostic settings, fuera de alcance del patrón.
  # storage_account_id → se gestiona por Resource Manager (control plane),
  # así que funciona con public_network_access = "Disabled".
  name                  = "ingest"
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}

# --- Expiración (TTL) ---------------------------------------------------------

resource "azurerm_storage_management_policy" "ttl" {
  storage_account_id = azurerm_storage_account.this.id

  rule {
    name    = "expire-ingest"
    enabled = true

    filters {
      blob_types = ["blockBlob"]
      # El prefijo DEBE empezar con el nombre del contenedor
      # (gotcha: prefix-includes-container).
      prefix_match = ["${azurerm_storage_container.ingest.name}/${var.object_prefix}"]
    }

    actions {
      base_blob {
        delete_after_days_since_creation_greater_than = var.ttl_days
      }
    }
  }
}

# --- Identidad del productor --------------------------------------------------

resource "azurerm_user_assigned_identity" "producer" {
  name                = "id-${var.name}-producer"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = var.tags
}

resource "azurerm_role_assignment" "producer_blob_writer" {
  # Scope mínimo posible sin ABAC: el contenedor (gotcha: rbac-scope-is-container).
  scope                = azurerm_storage_container.ingest.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.producer.principal_id
  principal_type       = "ServicePrincipal"
}

# --- Private Endpoint + DNS ---------------------------------------------------

resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  name                 = "link-${var.name}"
  private_dns_zone_id  = azurerm_private_dns_zone.blob.id
  virtual_network_id   = azurerm_virtual_network.this.id
  registration_enabled = false
  tags                 = var.tags
}

resource "azurerm_private_endpoint" "blob" {
  name                = "pe-${var.name}-blob"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  subnet_id           = azurerm_subnet.endpoints.id

  private_service_connection {
    name                           = "psc-${var.name}-blob"
    private_connection_resource_id = azurerm_storage_account.this.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  # Sin esto el FQDN resuelve a la IP pública y la request falla con 403
  # (gotcha: private-endpoint-needs-dns).
  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }

  tags = var.tags
}
