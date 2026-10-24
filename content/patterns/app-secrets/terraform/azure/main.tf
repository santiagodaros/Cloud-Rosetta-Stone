# Secretos de aplicación — Azure
#
# Key Vault con RBAC y soft delete + purge protection, accesible solo por Private Endpoint, leído con una
# user-assigned managed identity y con los accesos auditados en Log Analytics.
#
# El módulo NO crea el valor del secreto: un azurerm_key_vault_secret dejaría el valor en el state de Terraform.
# Cargalo fuera de banda con el rol Key Vault Secrets Officer, por la red privada.

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "this" {
  name     = "rg-${var.name}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "app" {
  name                = "vnet-${var.name}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  address_space       = [var.vnet_address_space]
  tags                = var.tags
}

resource "azurerm_subnet" "private_endpoints" {
  name                 = "snet-private-endpoints"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.app.name
  address_prefixes     = [var.private_endpoint_subnet_prefix]

  # Sin esto el NSG de abajo no se aplica a los Private Endpoints de la subnet.
  private_endpoint_network_policies = "Enabled"
}

# NSG de la subnet de Private Endpoints. Sin reglas propias rigen las de default (tráfico dentro de la VNet,
# deny del resto de Internet); sirve de punto de enganche para endurecerlas.
resource "azurerm_network_security_group" "private_endpoints" {
  name                = "nsg-${var.name}-private-endpoints"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = var.tags
}

resource "azurerm_subnet_network_security_group_association" "private_endpoints" {
  subnet_id                 = azurerm_subnet.private_endpoints.id
  network_security_group_id = azurerm_network_security_group.private_endpoints.id
}

# --- Identidad del workload ------------------------------------------------------

resource "azurerm_user_assigned_identity" "app" {
  name                = "id-${var.name}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = var.tags
}

# --- Vault -----------------------------------------------------------------------

resource "azurerm_key_vault" "this" {
  name                = "kv-${var.name}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # Autorización por RBAC y no por access policies (gotcha: access-policy-model-self-grant).
  rbac_authorization_enabled = true

  # Soft delete ya viene activo y no se puede apagar; purge protection tampoco se puede desactivar después
  # (gotcha: soft-delete-blocks-name-reuse).
  purge_protection_enabled   = true
  soft_delete_retention_days = var.soft_delete_retention_days

  # Solo por Private Endpoint (gotcha: private-endpoint-needs-linked-zone).
  public_network_access_enabled = false

  network_acls {
    default_action = "Deny"
    bypass         = "None"
  }

  tags = var.tags
}

# La app solo lee secretos. Rol Key Vault Secrets User a nivel de vault (gotcha: access-policy-model-self-grant).
resource "azurerm_role_assignment" "app_reads_secrets" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
  principal_type       = "ServicePrincipal"
}

# --- Acceso privado --------------------------------------------------------------

resource "azurerm_private_dns_zone" "vault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

# Sin este link, la VNet resuelve la IP pública del vault (gotcha: private-endpoint-needs-linked-zone).
resource "azurerm_private_dns_zone_virtual_network_link" "vault" {
  name                = "app"
  private_dns_zone_id = azurerm_private_dns_zone.vault.id
  virtual_network_id  = azurerm_virtual_network.app.id
  tags                = var.tags
}

resource "azurerm_private_endpoint" "vault" {
  name                = "pe-${var.name}-vault"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = var.tags

  private_service_connection {
    name                           = "vault"
    private_connection_resource_id = azurerm_key_vault.this.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "vault"
    private_dns_zone_ids = [azurerm_private_dns_zone.vault.id]
  }
}

# --- Auditoría -------------------------------------------------------------------

# Sin diagnostic setting los resource logs no se guardan (gotcha: audit-needs-diagnostic-setting).
resource "azurerm_monitor_diagnostic_setting" "vault_audit" {
  name                       = "audit"
  target_resource_id         = azurerm_key_vault.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "AuditEvent"
  }
}

# --- Clave opcional --------------------------------------------------------------

# Las claves del vault no son la clave que protege los secretos del propio vault
# (gotcha: vault-keys-do-not-encrypt-its-secrets). Sirven para cifrado propio de la app u otros servicios.
# Crearla es una operación de data plane: hace falta el rol y llegar al vault por la red privada.
resource "azurerm_role_assignment" "deployer_manages_keys" {
  count = var.create_app_key ? 1 : 0

  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Crypto Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_key_vault_key" "app" {
  count = var.create_app_key ? 1 : 0

  name         = "app-key"
  key_vault_id = azurerm_key_vault.this.id
  key_type     = "RSA"
  key_size     = 3072
  key_opts     = ["encrypt", "decrypt", "wrapKey", "unwrapKey"]

  expiration_date = "2030-01-01T00:00:00Z"

  rotation_policy {
    expire_after         = "P2Y"
    notify_before_expiry = "P30D"

    automatic {
      time_after_creation = "P1Y"
    }
  }

  depends_on = [azurerm_role_assignment.deployer_manages_keys, azurerm_private_endpoint.vault]
}
