# DNS privado híbrido — Azure
#
# DNS Private Resolver en el hub: inbound endpoint para on-premises, outbound
# endpoint + forwarding ruleset para corp.example.com, y una regla que manda la
# zona privada al inbound endpoint para que los spokes la resuelvan sin links.

locals {
  # Las reglas usan nombres terminados en punto.
  onprem_fqdn = "${trimsuffix(var.onprem_domain, ".")}."
  zone_fqdn   = "${trimsuffix(var.private_zone_name, ".")}."
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

# Una subnet por endpoint, delegada y sin otros recursos (gotcha: resolver-dedicated-subnets).
resource "azurerm_subnet" "inbound" {
  name                 = "snet-dns-inbound"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.inbound_subnet_prefix]

  delegation {
    name = "dns-resolver"
    service_delegation {
      name    = "Microsoft.Network/dnsResolvers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "outbound" {
  name                 = "snet-dns-outbound"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.outbound_subnet_prefix]

  delegation {
    name = "dns-resolver"
    service_delegation {
      name    = "Microsoft.Network/dnsResolvers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_network_security_group" "resolver" {
  name                = "nsg-${var.name}-dns"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = var.tags

  # UDP y TCP: las respuestas grandes caen a TCP.
  security_rule {
    name                       = "dns-from-onprem"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_address_prefixes    = var.onprem_cidrs
    source_port_range          = "*"
    destination_address_prefix = var.inbound_subnet_prefix
    destination_port_range     = "53"
  }
}

resource "azurerm_subnet_network_security_group_association" "inbound" {
  subnet_id                 = azurerm_subnet.inbound.id
  network_security_group_id = azurerm_network_security_group.resolver.id
}

resource "azurerm_subnet_network_security_group_association" "outbound" {
  subnet_id                 = azurerm_subnet.outbound.id
  network_security_group_id = azurerm_network_security_group.resolver.id
}

resource "azurerm_private_dns_resolver" "this" {
  name                = "dnspr-${var.name}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  virtual_network_id  = azurerm_virtual_network.hub.id
  tags                = var.tags
}

# IP estática: es la que se carga en los forwarders condicionales on-premises.
resource "azurerm_private_dns_resolver_inbound_endpoint" "this" {
  name                    = "in-${var.name}"
  private_dns_resolver_id = azurerm_private_dns_resolver.this.id
  location                = azurerm_private_dns_resolver.this.location
  tags                    = var.tags

  ip_configurations {
    subnet_id                    = azurerm_subnet.inbound.id
    private_ip_allocation_method = "Static"
    private_ip_address           = cidrhost(var.inbound_subnet_prefix, 4)
  }
}

resource "azurerm_private_dns_resolver_outbound_endpoint" "this" {
  name                    = "out-${var.name}"
  private_dns_resolver_id = azurerm_private_dns_resolver.this.id
  location                = azurerm_private_dns_resolver.this.location
  subnet_id               = azurerm_subnet.outbound.id
  tags                    = var.tags
}

# --- Zona privada (vinculada solo al hub; el inbound endpoint la resuelve) ------

resource "azurerm_private_dns_zone" "cloud" {
  name                = var.private_zone_name
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "hub" {
  name                 = "hub"
  private_dns_zone_id  = azurerm_private_dns_zone.cloud.id
  virtual_network_id   = azurerm_virtual_network.hub.id
  registration_enabled = false
  tags                 = var.tags
}

# --- Reglas de reenvío -----------------------------------------------------------

resource "azurerm_private_dns_resolver_dns_forwarding_ruleset" "this" {
  name                                       = "dnsfrs-${var.name}"
  resource_group_name                        = azurerm_resource_group.this.name
  location                                   = azurerm_resource_group.this.location
  private_dns_resolver_outbound_endpoint_ids = [azurerm_private_dns_resolver_outbound_endpoint.this.id]
  tags                                       = var.tags
}

resource "azurerm_private_dns_resolver_forwarding_rule" "onprem" {
  name                      = "onprem"
  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.this.id
  domain_name               = local.onprem_fqdn
  enabled                   = true

  dynamic "target_dns_servers" {
    for_each = var.onprem_dns_servers
    content {
      ip_address = target_dns_servers.value
      port       = 53
    }
  }
}

# Los spokes resuelven la zona privada vía el inbound endpoint del hub.
resource "azurerm_private_dns_resolver_forwarding_rule" "cloud_zone" {
  name                      = "cloud-zone"
  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.this.id
  domain_name               = local.zone_fqdn
  enabled                   = true

  target_dns_servers {
    ip_address = azurerm_private_dns_resolver_inbound_endpoint.this.ip_configurations[0].private_ip_address
    port       = 53
  }
}

# Solo spokes: linkear el hub, con una regla que apunta a su propio inbound
# endpoint, genera un loop (gotcha: ruleset-hub-loop).
resource "azurerm_private_dns_resolver_virtual_network_link" "spoke" {
  for_each = var.spoke_vnet_ids

  name                      = "spoke-${each.key}"
  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.this.id
  virtual_network_id        = each.value
}
