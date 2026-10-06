# Web API privada Zero Trust — Azure
#
# Container Apps en un environment interno (ILB) con identidad administrada,
# conectándose por Private Endpoint a PostgreSQL Flexible Server que solo
# acepta autenticación Entra ID (sin contraseñas).

data "azurerm_client_config" "current" {}

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

# Dedicada al environment y delegada (gotcha: aca-subnet-sizing).
resource "azurerm_subnet" "aca" {
  name                 = "snet-aca"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.aca_subnet_prefix]

  delegation {
    name = "aca"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "endpoints" {
  name                 = "snet-private-endpoints"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.endpoints_subnet_prefix]
}

resource "azurerm_network_security_group" "this" {
  for_each            = { aca = azurerm_subnet.aca.id, endpoints = azurerm_subnet.endpoints.id }
  name                = "nsg-${var.name}-${each.key}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = var.tags
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each                  = { aca = azurerm_subnet.aca.id, endpoints = azurerm_subnet.endpoints.id }
  subnet_id                 = each.value
  network_security_group_id = azurerm_network_security_group.this[each.key].id
}

# --- Container Apps (environment interno) -------------------------------------

resource "azurerm_container_app_environment" "this" {
  name                           = "cae-${var.name}"
  resource_group_name            = azurerm_resource_group.this.name
  location                       = azurerm_resource_group.this.location
  infrastructure_subnet_id       = azurerm_subnet.aca.id
  internal_load_balancer_enabled = true

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }

  tags = var.tags

  depends_on = [azurerm_subnet_network_security_group_association.this]
}

# Sin esta zona nadie resuelve <app>.<default_domain> (gotcha: aca-internal-needs-private-dns).
resource "azurerm_private_dns_zone" "aca" {
  name                = azurerm_container_app_environment.this.default_domain
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_private_dns_a_record" "aca" {
  for_each            = toset(["*", "@"])
  name                = each.key
  private_dns_zone_id = azurerm_private_dns_zone.aca.id
  ttl                 = 300
  records             = [azurerm_container_app_environment.this.static_ip_address]
}

resource "azurerm_private_dns_zone_virtual_network_link" "aca" {
  name                 = "link-${var.name}-aca"
  private_dns_zone_id  = azurerm_private_dns_zone.aca.id
  virtual_network_id   = azurerm_virtual_network.this.id
  registration_enabled = false
  tags                 = var.tags
}

resource "azurerm_user_assigned_identity" "api" {
  name                = "id-${var.name}-api"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = var.tags
}

resource "azurerm_container_app" "api" {
  name                         = "ca-${var.name}-api"
  resource_group_name          = azurerm_resource_group.this.name
  container_app_environment_id = azurerm_container_app_environment.this.id
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.api.id]
  }

  ingress {
    # En un environment interno, external_enabled = true significa "toda la VNet";
    # false limita el acceso a otras apps del mismo environment.
    external_enabled           = true
    target_port                = var.container_port
    allow_insecure_connections = false

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = 0
    max_replicas = var.max_replicas

    container {
      name   = "api"
      image  = var.container_image
      cpu    = 0.25
      memory = "0.5Gi"

      # Sin contraseña: la app pide un token para ossrdbms-aad con esta identidad
      # (gotcha: pg-entra-token-resource).
      env {
        name  = "AZURE_CLIENT_ID"
        value = azurerm_user_assigned_identity.api.client_id
      }
      env {
        name  = "PGHOST"
        value = azurerm_postgresql_flexible_server.this.fqdn
      }
      env {
        name  = "PGUSER"
        value = azurerm_user_assigned_identity.api.name
      }
      env {
        name  = "PGDATABASE"
        value = var.database_name
      }
      env {
        name  = "PGSSLMODE"
        value = "require"
      }
    }
  }

  tags = var.tags
}

# --- PostgreSQL (solo Entra ID, sin acceso público) ---------------------------

resource "azurerm_postgresql_flexible_server" "this" {
  #checkov:skip=CKV_AZURE_136:Backup geo-redundante opcional; duplica costo de backup. Activar en producción crítica.
  name                          = var.postgres_server_name
  resource_group_name           = azurerm_resource_group.this.name
  location                      = azurerm_resource_group.this.location
  version                       = "17"
  sku_name                      = var.postgres_sku
  storage_mb                    = 32768
  backup_retention_days         = 7
  geo_redundant_backup_enabled  = false
  public_network_access_enabled = false

  # Modo "acceso público" + Private Endpoint: no se puede cambiar después
  # (gotcha: pg-network-mode-is-permanent).
  authentication {
    active_directory_auth_enabled = true
    password_auth_enabled         = false
    tenant_id                     = data.azurerm_client_config.current.tenant_id
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [zone]
  }
}

resource "azurerm_postgresql_flexible_server_active_directory_administrator" "this" {
  server_name         = azurerm_postgresql_flexible_server.this.name
  resource_group_name = azurerm_resource_group.this.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  object_id           = var.entra_admin.object_id
  principal_name      = var.entra_admin.principal_name
  principal_type      = var.entra_admin.principal_type
}

resource "azurerm_postgresql_flexible_server_database" "app" {
  name      = var.database_name
  server_id = azurerm_postgresql_flexible_server.this.id
  collation = "en_US.utf8"
  charset   = "UTF8"
}

resource "azurerm_private_dns_zone" "postgres" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                 = "link-${var.name}-postgres"
  private_dns_zone_id  = azurerm_private_dns_zone.postgres.id
  virtual_network_id   = azurerm_virtual_network.this.id
  registration_enabled = false
  tags                 = var.tags
}

resource "azurerm_private_endpoint" "postgres" {
  name                = "pe-${var.name}-postgres"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  subnet_id           = azurerm_subnet.endpoints.id

  private_service_connection {
    name                           = "psc-${var.name}-postgres"
    private_connection_resource_id = azurerm_postgresql_flexible_server.this.id
    subresource_names              = ["postgresqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.postgres.id]
  }

  tags = var.tags
}
