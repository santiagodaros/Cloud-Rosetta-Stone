# Tests sin credenciales ni recursos reales: mock_provider + command = plan.

mock_provider "azurerm" {}

variables {
  name               = "dns-test"
  onprem_dns_servers = ["192.168.10.10", "192.168.10.11"]
  onprem_cidrs       = ["192.168.0.0/16"]
  spoke_vnet_ids = {
    app = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-app/providers/Microsoft.Network/virtualNetworks/vnet-app"
  }
}

run "dedicated_delegated_subnets" {
  command = plan

  assert {
    condition     = alltrue([for s in [azurerm_subnet.inbound, azurerm_subnet.outbound] : s.delegation[0].service_delegation[0].name == "Microsoft.Network/dnsResolvers"])
    error_message = "Cada endpoint necesita su subnet delegada a Microsoft.Network/dnsResolvers."
  }

  assert {
    condition     = azurerm_private_dns_resolver_inbound_endpoint.this.ip_configurations[0].private_ip_address == "10.10.0.4"
    error_message = "El inbound endpoint tiene que tener IP estática (la que usa on-premises)."
  }
}

run "rules_are_fqdn_and_target_onprem" {
  command = plan

  assert {
    condition     = azurerm_private_dns_resolver_forwarding_rule.onprem.domain_name == "corp.example.com."
    error_message = "El dominio de la regla tiene que terminar en punto."
  }

  assert {
    condition     = length(azurerm_private_dns_resolver_forwarding_rule.onprem.target_dns_servers) == 2
    error_message = "La regla tiene que apuntar a todos los DNS on-premises."
  }

  assert {
    condition     = azurerm_private_dns_resolver_forwarding_rule.cloud_zone.target_dns_servers[0].ip_address == "10.10.0.4"
    error_message = "La zona privada se reenvía al inbound endpoint del hub."
  }
}

run "only_spokes_are_linked" {
  command = plan

  assert {
    condition     = keys(azurerm_private_dns_resolver_virtual_network_link.spoke) == ["app"]
    error_message = "El ruleset se linkea a los spokes, no al hub."
  }
}

run "rejects_azure_dns_as_target" {
  command = plan

  variables {
    onprem_dns_servers = ["168.63.129.16"]
  }

  expect_failures = [var.onprem_dns_servers]
}

run "rejects_oversized_subnet" {
  command = plan

  variables {
    inbound_subnet_prefix = "10.10.0.0/23"
  }

  expect_failures = [var.inbound_subnet_prefix]
}
