# Origen protegido detrás de CDN — Azure
#
# Front Door Premium con un origen de blobs al que llega por Private Link: la Storage Account no tiene
# acceso de red público y solo la conexión privada de Front Door (que hay que aprobar a mano) la alcanza.

resource "azurerm_resource_group" "this" {
  name     = "rg-${var.name}"
  location = var.location
  tags     = var.tags
}

# --- Origen -----------------------------------------------------------------------

resource "azurerm_storage_account" "origin" {
  #checkov:skip=CKV_AZURE_59:La lectura anónima de los blobs es lo que Front Door necesita en un origen sin SAS (gotcha: private-link-origin-needs-anonymous-or-sas); con la red pública deshabilitada solo la alcanza el private endpoint.
  #checkov:skip=CKV_AZURE_33:El logging de la cola no aplica: la cuenta no usa Queue storage.
  #checkov:skip=CKV_AZURE_190:Misma razón que CKV_AZURE_59: Front Door lee los blobs de forma anónima.
  #checkov:skip=CKV2_AZURE_47:Misma razón que CKV_AZURE_59: Front Door lee los blobs de forma anónima.
  #checkov:skip=CKV2_AZURE_33:El private endpoint lo crea Front Door en una red administrada por Azure, fuera de esta configuración; la conexión se aprueba en la cuenta.
  #checkov:skip=CKV2_AZURE_40:Cambiar container_access_type en un contenedor existente usa Shared Key (nota del provider), así que la clave se deja habilitada.
  #checkov:skip=CKV2_AZURE_1:El cifrado con clave propia (CMK) requiere un Key Vault y una identidad que el módulo no crea; la cuenta usa el cifrado de Microsoft por defecto.
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
  account_kind             = "StorageV2"
  min_tls_version          = "TLS1_2"

  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = true
  public_network_access           = "Disabled"
  shared_access_key_enabled       = true

  sas_policy {
    expiration_period = "07.00:00:00"
    expiration_action = "Log"
  }

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 7
    }

    container_delete_retention_policy {
      days = 7
    }
  }

  tags = var.tags
}

# "blob" = lectura anónima de cada blob sin listar el contenedor
# (gotcha: private-link-origin-needs-anonymous-or-sas).
resource "azurerm_storage_container" "content" {
  #checkov:skip=CKV_AZURE_34:El acceso anónimo de lectura es deliberado (ver la Storage Account); el contenedor solo se alcanza por el private endpoint de Front Door.
  #checkov:skip=CKV2_AZURE_21:Los logs de lectura del blob service dependen de un workspace de diagnóstico que el módulo no crea.
  name                  = var.container_name
  storage_account_id    = azurerm_storage_account.origin.id
  container_access_type = "blob"
}

# --- CDN ---------------------------------------------------------------------------

# Private Link hacia el origen solo está en el nivel Premium (gotcha: premium-private-link-pending-approval).
resource "azurerm_cdn_frontdoor_profile" "this" {
  name                = "afd-${var.name}"
  resource_group_name = azurerm_resource_group.this.name
  sku_name            = "Premium_AzureFrontDoor"
  tags                = var.tags
}

resource "azurerm_cdn_frontdoor_endpoint" "this" {
  name                     = "fde-${var.name}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id
  tags                     = var.tags
}

# Grupo exclusivo de orígenes privados: no se mezclan públicos y privados
# (gotcha: no-mixed-public-private-origin-group).
resource "azurerm_cdn_frontdoor_origin_group" "private" {
  name                     = "og-private"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id

  load_balancing {}
}

# La conexión del private endpoint queda pendiente hasta que se aprueba en la Storage Account
# (gotcha: premium-private-link-pending-approval). Terraform no la aprueba.
resource "azurerm_cdn_frontdoor_origin" "blob" {
  name                          = "blob"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.private.id
  enabled                       = true

  certificate_name_check_enabled = true
  host_name                      = azurerm_storage_account.origin.primary_blob_host
  origin_host_header             = azurerm_storage_account.origin.primary_blob_host
  priority                       = 1
  weight                         = 1000

  private_link {
    request_message        = "Front Door ${var.name}: aprobar para servir ${var.container_name}"
    target_type            = "blob"
    location               = azurerm_storage_account.origin.location
    private_link_target_id = azurerm_storage_account.origin.id
  }
}

resource "azurerm_cdn_frontdoor_custom_domain" "this" {
  count = var.custom_domain == null ? 0 : 1

  name                     = "cd-${var.name}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id
  host_name                = var.custom_domain

  tls {
    certificate_type = "ManagedCertificate"
  }
}

resource "azurerm_cdn_frontdoor_custom_domain_association" "this" {
  count = var.custom_domain == null ? 0 : 1

  cdn_frontdoor_custom_domain_id = azurerm_cdn_frontdoor_custom_domain.this[0].id
  cdn_frontdoor_route_ids        = [azurerm_cdn_frontdoor_route.this.id]
}

# El origin path es el contenedor: sin él los pedidos buscan un contenedor que no existe.
resource "azurerm_cdn_frontdoor_route" "this" {
  name                          = "route-${var.name}"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.this.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.private.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.blob.id]
  cdn_frontdoor_origin_path     = "/${var.container_name}"

  patterns_to_match      = ["/*"]
  supported_protocols    = ["Http", "Https"]
  https_redirect_enabled = true
  forwarding_protocol    = "HttpsOnly"
  link_to_default_domain = true

  cdn_frontdoor_custom_domain_ids = var.custom_domain == null ? [] : [azurerm_cdn_frontdoor_custom_domain.this[0].id]

  cache {
    query_string_caching_behavior = "IgnoreQueryString"
    compression_enabled           = true
    content_types_to_compress     = ["text/html", "text/css", "application/javascript", "application/json", "image/svg+xml"]
  }
}

# --- WAF ---------------------------------------------------------------------------

resource "azurerm_cdn_frontdoor_firewall_policy" "this" {
  name                = "waf${var.name}"
  resource_group_name = azurerm_resource_group.this.name
  sku_name            = azurerm_cdn_frontdoor_profile.this.sku_name
  enabled             = true
  mode                = var.waf_mode
  tags                = var.tags

  managed_rule {
    type    = "Microsoft_DefaultRuleSet"
    version = "2.1"
    action  = "Block"
  }
}

resource "azurerm_cdn_frontdoor_security_policy" "this" {
  name                     = "sp-${var.name}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id

  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = azurerm_cdn_frontdoor_firewall_policy.this.id

      association {
        patterns_to_match = ["/*"]

        domain {
          cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_endpoint.this.id
        }

        dynamic "domain" {
          for_each = azurerm_cdn_frontdoor_custom_domain.this
          content {
            cdn_frontdoor_domain_id = domain.value.id
          }
        }
      }
    }
  }
}
