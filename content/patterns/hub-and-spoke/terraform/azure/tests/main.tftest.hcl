# Tests sin credenciales ni recursos reales: mock_provider + command = plan.

mock_provider "azurerm" {}

variables {
  name = "hub-test"
  spokes = {
    app  = { address_space = "10.20.0.0/24" }
    data = { address_space = "10.30.0.0/24" }
  }
}

run "firewall_subnet_name_and_size" {
  command = plan

  assert {
    condition     = azurerm_subnet.firewall.name == "AzureFirewallSubnet" && one(azurerm_subnet.firewall.address_prefixes) == "10.10.0.0/26"
    error_message = "El firewall exige la subnet AzureFirewallSubnet de /26 como mínimo."
  }
}

run "spokes_peer_with_forwarded_traffic" {
  command = plan

  assert {
    condition     = alltrue([for p in concat(values(azurerm_virtual_network_peering.hub_to_spoke), values(azurerm_virtual_network_peering.spoke_to_hub)) : p.allow_forwarded_traffic])
    error_message = "Los peerings tienen que aceptar tráfico reenviado para que el firewall pueda rutear spoke a spoke."
  }

  assert {
    condition     = toset(keys(azurerm_virtual_network_peering.hub_to_spoke)) == toset(["app", "data"])
    error_message = "Cada spoke tiene su peering desde el hub."
  }
}

run "spoke_default_route_goes_to_the_firewall" {
  command = plan

  assert {
    condition     = alltrue([for rt in azurerm_route_table.spoke : toset([for r in rt.route : "${r.address_prefix}|${r.next_hop_type}"]) == toset(["0.0.0.0/0|VirtualAppliance"])])
    error_message = "Cada spoke necesita una UDR 0.0.0.0/0 con next hop VirtualAppliance."
  }

  assert {
    condition     = toset(keys(azurerm_subnet_route_table_association.spoke)) == toset(["app", "data"])
    error_message = "La route table tiene que estar asociada a la subnet de cada spoke."
  }
}

run "gateway_transit_flags_move_together" {
  command = plan

  variables {
    enable_gateway_transit = true
  }

  assert {
    condition     = alltrue([for p in azurerm_virtual_network_peering.hub_to_spoke : p.allow_gateway_transit]) && alltrue([for p in azurerm_virtual_network_peering.spoke_to_hub : p.use_remote_gateways])
    error_message = "El hub permite gateway transit y los spokes usan el gateway remoto."
  }
}

run "spoke_to_spoke_is_blocked_by_default" {
  command = plan

  assert {
    condition     = length(azurerm_firewall_policy_rule_collection_group.spokes.network_rule_collection) == 0
    error_message = "Sin allow_spoke_to_spoke no debe haber regla que permita el tráfico entre spokes."
  }
}

run "spoke_to_spoke_rule_when_allowed" {
  command = plan

  variables {
    allow_spoke_to_spoke = true
  }

  assert {
    condition     = length(azurerm_firewall_policy_rule_collection_group.spokes.network_rule_collection) == 1
    error_message = "Con allow_spoke_to_spoke tiene que haber una colección de reglas de red."
  }
}

run "rejects_too_small_firewall_subnet" {
  command = plan

  variables {
    firewall_subnet_prefix = "10.10.0.0/27"
  }

  expect_failures = [var.firewall_subnet_prefix]
}

run "rejects_basic_sku" {
  command = plan

  variables {
    firewall_sku_tier = "Basic"
  }

  expect_failures = [var.firewall_sku_tier]
}
