# Salida a internet controlada — Azure
#
# Los workloads viven en una subnet privada y rutean 0.0.0.0/0 a Azure Firewall, que solo deja salir por HTTPS a los
# FQDN permitidos. El NAT Gateway se asocia a AzureFirewallSubnet: así los destinos ven sus IPs públicas fijas.

locals {
  # StandardV2 exige IPs públicas StandardV2; Standard exige IPs Standard.
  nat_public_ip_sku = var.nat_sku_name == "StandardV2" ? "StandardV2" : "Standard"

  # StandardV2 no lleva zonas: es zona-redundante por defecto (gotcha: nat-standard-zonal).
  nat_zones = var.nat_sku_name == "Standard" && var.nat_zone != null ? [var.nat_zone] : null
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${var.name}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "this" {
  name                = "vnet-${var.name}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  address_space       = [var.vnet_address_space]
  tags                = var.tags
}

# Subnet privada: sin salida implícita; la salida es explícita vía firewall + NAT Gateway
# (gotcha: default-outbound-access).
resource "azurerm_subnet" "workloads" {
  name                            = "snet-workloads"
  resource_group_name             = azurerm_resource_group.this.name
  virtual_network_name            = azurerm_virtual_network.this.name
  address_prefixes                = [var.workload_subnet_prefix]
  default_outbound_access_enabled = false
}

resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.firewall_subnet_prefix]
}

resource "azurerm_network_security_group" "workloads" {
  name                = "nsg-${var.name}-workloads"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = var.tags
}

resource "azurerm_subnet_network_security_group_association" "workloads" {
  subnet_id                 = azurerm_subnet.workloads.id
  network_security_group_id = azurerm_network_security_group.workloads.id
}

# --- NAT Gateway: las IPs que ve el tercero --------------------------------------------

resource "azurerm_public_ip" "nat" {
  count = var.nat_public_ip_count

  name                = "pip-${var.name}-nat-${count.index}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  allocation_method   = "Static"
  sku                 = local.nat_public_ip_sku
  tags                = var.tags
}

resource "azurerm_nat_gateway" "this" {
  name                = "ng-${var.name}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku_name            = var.nat_sku_name
  zones               = local.nat_zones
  tags                = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "this" {
  count = var.nat_public_ip_count

  nat_gateway_id       = azurerm_nat_gateway.this.id
  public_ip_address_id = azurerm_public_ip.nat[count.index].id
}

# En AzureFirewallSubnet, no en la subnet de los workloads: la ruta 0.0.0.0/0 al firewall pisaría al NAT Gateway
# de esa subnet (gotcha: udr-overrides-nat-gateway).
resource "azurerm_subnet_nat_gateway_association" "firewall" {
  subnet_id      = azurerm_subnet.firewall.id
  nat_gateway_id = azurerm_nat_gateway.this.id
}

# --- Azure Firewall con policy ------------------------------------------------------------

resource "azurerm_public_ip" "firewall" {
  name                = "pip-${var.name}-fw"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_firewall_policy" "this" {
  name                     = "fwp-${var.name}"
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  sku                      = "Standard"
  threat_intelligence_mode = "Deny"
  tags                     = var.tags

  # DNS proxy: lo necesitan los FQDN en reglas de red (gotcha: fqdn-rules-need-dns-proxy).
  dns {
    proxy_enabled = true
  }
}

# FQDN en reglas de aplicación: HTTP/S por SNI, sin terminar TLS (gotcha: fqdn-rules-need-dns-proxy).
resource "azurerm_firewall_policy_rule_collection_group" "egress" {
  name               = "rcg-${var.name}-egress"
  firewall_policy_id = azurerm_firewall_policy.this.id
  priority           = 500

  application_rule_collection {
    name     = "allow-fqdns"
    priority = 100
    action   = "Allow"

    rule {
      name              = "https-allowed-fqdns"
      source_addresses  = [var.workload_subnet_prefix]
      destination_fqdns = var.allowed_fqdns

      protocols {
        type = "Https"
        port = 443
      }
    }
  }
}

resource "azurerm_firewall" "this" {
  name                = "fw-${var.name}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.this.id
  tags                = var.tags

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }

  depends_on = [azurerm_subnet_nat_gateway_association.firewall]
}

# --- Ruta de los workloads hacia el firewall --------------------------------------------------

resource "azurerm_route_table" "workloads" {
  name                = "rt-${var.name}-workloads"
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

resource "azurerm_subnet_route_table_association" "workloads" {
  subnet_id      = azurerm_subnet.workloads.id
  route_table_id = azurerm_route_table.workloads.id
}
