# Hub-and-spoke con inspección centralizada — Azure
#
# VNet hub con Azure Firewall (policy incluida) y, por cada spoke, una VNet, un peering en
# los dos sentidos y una UDR 0.0.0.0/0 hacia la IP privada del firewall.

locals {
  spoke_cidrs = [for s in var.spokes : s.address_space]
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${var.name}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-${var.name}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  address_space       = [var.hub_address_space]
  tags                = var.tags
}

# Nombre fijo, /26 como mínimo y sin NSG (gotcha: firewall-subnet-name-size-no-nsg).
resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.firewall_subnet_prefix]
}

resource "azurerm_public_ip" "firewall" {
  name                = "pip-${var.name}-fw"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_firewall_policy" "this" {
  #checkov:skip=CKV_AZURE_220:IDPS solo existe en el SKU Premium; el módulo lo pone en Deny cuando firewall_sku_tier = "Premium" (bloque dinámico que el análisis estático no resuelve).
  name                     = "afwp-${var.name}"
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  sku                      = var.firewall_sku_tier
  threat_intelligence_mode = "Deny"
  tags                     = var.tags

  dynamic "intrusion_detection" {
    for_each = var.firewall_sku_tier == "Premium" ? [1] : []
    content {
      mode = "Deny"
    }
  }
}

# Sin reglas, el firewall bloquea el tráfico de los spokes: se permite solo lo que se declara.
resource "azurerm_firewall_policy_rule_collection_group" "spokes" {
  name               = "spokes"
  firewall_policy_id = azurerm_firewall_policy.this.id
  priority           = 500

  dynamic "network_rule_collection" {
    for_each = var.allow_spoke_to_spoke && length(local.spoke_cidrs) > 1 ? [1] : []
    content {
      name     = "spoke-to-spoke"
      priority = 1000
      action   = "Allow"

      rule {
        name                  = "spokes-between-them"
        protocols             = ["Any"]
        source_addresses      = local.spoke_cidrs
        destination_addresses = local.spoke_cidrs
        destination_ports     = ["*"]
      }
    }
  }

  dynamic "application_rule_collection" {
    for_each = length(var.allowed_egress_fqdns) > 0 ? [1] : []
    content {
      name     = "egress"
      priority = 2000
      action   = "Allow"

      rule {
        name              = "https-egress"
        source_addresses  = local.spoke_cidrs
        destination_fqdns = var.allowed_egress_fqdns

        protocols {
          type = "Https"
          port = 443
        }
      }
    }
  }
}

# Se factura por hora de despliegue (gotcha: firewall-hourly-fee-and-direct-peering).
resource "azurerm_firewall" "this" {
  #checkov:skip=CKV_AZURE_216:El modo de threat intelligence se configura en la policy (threat_intelligence_mode = "Deny" en azurerm_firewall_policy.this); el check solo inspecciona el atributo threat_intel_mode del azurerm_firewall clásico. No se verificó qué hace la API de Azure si se setea también en el firewall, así que no se agrega para evitar drift.
  name                = "afw-${var.name}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku_name            = "AZFW_VNet"
  sku_tier            = var.firewall_sku_tier
  firewall_policy_id  = azurerm_firewall_policy.this.id
  tags                = var.tags

  ip_configuration {
    name                 = "ipconfig"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }
}

# --- Spokes ----------------------------------------------------------------------

resource "azurerm_virtual_network" "spoke" {
  for_each = var.spokes

  name                = "vnet-${var.name}-${each.key}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  address_space       = [each.value.address_space]
  tags                = var.tags
}

resource "azurerm_subnet" "workload" {
  for_each = var.spokes

  name                 = "snet-workload"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.spoke[each.key].name
  address_prefixes     = [each.value.address_space]
}

# NSG de la subnet de workload (la del firewall no admite NSG; esta sí). Solo las reglas por
# defecto de Azure: lo que cada workload necesite se agrega fuera del patrón.
resource "azurerm_network_security_group" "workload" {
  for_each = var.spokes

  name                = "nsg-${var.name}-${each.key}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = var.tags
}

resource "azurerm_subnet_network_security_group_association" "workload" {
  for_each = var.spokes

  subnet_id                 = azurerm_subnet.workload[each.key].id
  network_security_group_id = azurerm_network_security_group.workload[each.key].id
}

# El peering no es transitivo: spoke a spoke pasa por el firewall solo si la UDR lo fuerza
# y los peerings aceptan tráfico reenviado (gotcha: spoke-to-spoke-needs-udr-and-forwarded-traffic).
# Los tres flags de gateway transit van juntos (gotcha: gateway-transit-flags).
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  for_each = var.spokes

  name                         = "hub-to-${each.key}"
  resource_group_name          = azurerm_resource_group.this.name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke[each.key].id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = var.enable_gateway_transit
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  for_each = var.spokes

  name                         = "${each.key}-to-hub"
  resource_group_name          = azurerm_resource_group.this.name
  virtual_network_name         = azurerm_virtual_network.spoke[each.key].name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = var.enable_gateway_transit
}

# 0.0.0.0/0 al firewall. Los otros spokes no están peereados con este, así que no hay una
# ruta de peering que compita; si resumís prefijos, cuidá el longest prefix match
# (gotcha: peering-routes-beat-summarized-udr).
resource "azurerm_route_table" "spoke" {
  for_each = var.spokes

  name                = "rt-${var.name}-${each.key}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = var.tags

  route {
    name                   = "default-to-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.this.ip_configuration[0].private_ip_address
  }
}

resource "azurerm_subnet_route_table_association" "spoke" {
  for_each = var.spokes

  subnet_id      = azurerm_subnet.workload[each.key].id
  route_table_id = azurerm_route_table.spoke[each.key].id
}
