# Tests sin credenciales ni recursos reales: mock_provider + command = plan.

mock_provider "azurerm" {}

variables {
  name          = "egress-test"
  allowed_fqdns = ["api.example.com", "*.updates.example.com"]
}

run "workload_subnet_is_private" {
  command = plan

  assert {
    condition     = azurerm_subnet.workloads.default_outbound_access_enabled == false
    error_message = "La subnet de los workloads tiene que ser privada (default_outbound_access_enabled = false)."
  }

  assert {
    condition     = azurerm_subnet.firewall.name == "AzureFirewallSubnet"
    error_message = "El firewall exige una subnet llamada AzureFirewallSubnet."
  }
}

run "nat_gateway_is_zone_redundant_by_default" {
  command = plan

  assert {
    condition     = azurerm_nat_gateway.this.sku_name == "StandardV2"
    error_message = "Por defecto el NAT Gateway es StandardV2 (zona-redundante)."
  }

  assert {
    condition     = alltrue([for ip in azurerm_public_ip.nat : ip.sku == "StandardV2" && ip.allocation_method == "Static"])
    error_message = "StandardV2 exige IPs públicas StandardV2 y estáticas."
  }

  assert {
    condition     = length(azurerm_public_ip.nat) == 1
    error_message = "Por defecto hay una IP pública de salida."
  }
}

run "standard_nat_gateway_uses_standard_ips_and_a_zone" {
  command = plan

  variables {
    nat_sku_name        = "Standard"
    nat_zone            = "1"
    nat_public_ip_count = 2
  }

  assert {
    condition     = azurerm_nat_gateway.this.sku_name == "Standard" && toset(azurerm_nat_gateway.this.zones) == toset(["1"])
    error_message = "Un NAT Gateway Standard va en una zona."
  }

  assert {
    condition     = length(azurerm_public_ip.nat) == 2 && alltrue([for ip in azurerm_public_ip.nat : ip.sku == "Standard"])
    error_message = "Standard exige IPs públicas Standard, tantas como nat_public_ip_count."
  }
}

run "firewall_filters_by_fqdn_with_dns_proxy" {
  command = plan

  assert {
    condition     = azurerm_firewall_policy.this.dns[0].proxy_enabled
    error_message = "La policy tiene que habilitar DNS proxy."
  }

  assert {
    condition     = azurerm_firewall_policy_rule_collection_group.egress.application_rule_collection[0].action == "Allow"
    error_message = "La colección de aplicación permite los FQDN listados."
  }

  assert {
    condition     = toset(azurerm_firewall_policy_rule_collection_group.egress.application_rule_collection[0].rule[0].destination_fqdns) == toset(var.allowed_fqdns)
    error_message = "La regla tiene que apuntar a los FQDN permitidos."
  }

  assert {
    condition     = azurerm_firewall_policy_rule_collection_group.egress.application_rule_collection[0].rule[0].source_addresses[0] == var.workload_subnet_prefix
    error_message = "La regla aplica a la subnet de los workloads."
  }
}

run "firewall_sku" {
  command = plan

  assert {
    condition     = azurerm_firewall.this.sku_name == "AZFW_VNet" && azurerm_firewall.this.sku_tier == "Standard"
    error_message = "El firewall es Standard en VNet (necesario para FQDN en reglas de red)."
  }
}

run "rejects_wildcard_only_allowlist" {
  command = plan

  variables {
    allowed_fqdns = ["*"]
  }

  expect_failures = [var.allowed_fqdns]
}

run "rejects_small_firewall_subnet" {
  command = plan

  variables {
    firewall_subnet_prefix = "10.20.0.0/27"
  }

  expect_failures = [var.firewall_subnet_prefix]
}
