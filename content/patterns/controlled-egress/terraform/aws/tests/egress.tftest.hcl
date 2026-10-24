# Tests sin credenciales ni recursos reales: mock_provider + command = plan.

mock_provider "aws" {}

variables {
  name   = "egress-test"
  vpc_id = "vpc-0123456789abcdef0"
  az_config = {
    "us-east-1a" = {
      public_subnet_id       = "subnet-0aaaaaaaaaaaaaaa1"
      firewall_subnet_id     = "subnet-0aaaaaaaaaaaaaaa2"
      private_route_table_id = "rtb-0aaaaaaaaaaaaaaa3"
      public_route_table_id  = "rtb-0aaaaaaaaaaaaaaa4"
    }
    "us-east-1b" = {
      public_subnet_id       = "subnet-0bbbbbbbbbbbbbbb1"
      firewall_subnet_id     = "subnet-0bbbbbbbbbbbbbbb2"
      private_route_table_id = "rtb-0bbbbbbbbbbbbbbb3"
      public_route_table_id  = "rtb-0bbbbbbbbbbbbbbb4"
    }
  }
  private_cidrs   = ["10.0.0.0/20"]
  allowed_domains = ["api.example.com", ".updates.example.com"]
}

run "one_nat_gateway_per_az" {
  command = plan

  assert {
    condition     = toset(keys(aws_nat_gateway.this)) == toset(["us-east-1a", "us-east-1b"])
    error_message = "Tiene que haber un NAT gateway por AZ."
  }

  assert {
    condition     = aws_nat_gateway.this["us-east-1a"].subnet_id == "subnet-0aaaaaaaaaaaaaaa1" && aws_nat_gateway.this["us-east-1b"].subnet_id == "subnet-0bbbbbbbbbbbbbbb1"
    error_message = "Cada NAT gateway va en la subnet pública de su AZ."
  }

  assert {
    condition     = toset(keys(aws_eip.nat)) == toset(["us-east-1a", "us-east-1b"])
    error_message = "Cada NAT gateway tiene su Elastic IP."
  }
}

run "domain_allowlist_covers_http_and_tls" {
  command = plan

  assert {
    condition     = aws_networkfirewall_rule_group.domains.type == "STATEFUL"
    error_message = "La regla de dominios es stateful."
  }

  assert {
    condition     = aws_networkfirewall_rule_group.domains.rule_group[0].rules_source[0].rules_source_list[0].generated_rules_type == "ALLOWLIST"
    error_message = "La lista de dominios tiene que ser un ALLOWLIST."
  }

  assert {
    condition     = toset(aws_networkfirewall_rule_group.domains.rule_group[0].rules_source[0].rules_source_list[0].target_types) == toset(["HTTP_HOST", "TLS_SNI"])
    error_message = "Hay que inspeccionar HTTP (Host) y HTTPS (SNI)."
  }

  assert {
    condition     = toset(aws_networkfirewall_rule_group.domains.rule_group[0].rules_source[0].rules_source_list[0].targets) == toset(var.allowed_domains)
    error_message = "La lista tiene que contener los dominios permitidos."
  }
}

run "home_net_includes_private_cidrs" {
  command = plan

  assert {
    condition     = toset(one(aws_networkfirewall_rule_group.domains.rule_group[0].rule_variables[0].ip_sets).ip_set[0].definition) == toset(var.private_cidrs)
    error_message = "HOME_NET tiene que incluir los CIDR privados para que se inspeccione su tráfico."
  }
}

run "policy_forwards_to_stateful_engine_with_default_order" {
  command = plan

  assert {
    condition     = contains(aws_networkfirewall_firewall_policy.this.firewall_policy[0].stateless_default_actions, "aws:forward_to_sfe")
    error_message = "El tráfico sin regla stateless tiene que ir al motor stateful."
  }

  assert {
    condition     = aws_networkfirewall_firewall_policy.this.firewall_policy[0].stateful_engine_options[0].rule_order == "DEFAULT_ACTION_ORDER"
    error_message = "La lista de dominios genera el drop por defecto solo con default action order."
  }
}

run "firewall_has_an_endpoint_per_az" {
  command = plan

  assert {
    condition     = toset([for m in aws_networkfirewall_firewall.this.subnet_mapping : m.subnet_id]) == toset(["subnet-0aaaaaaaaaaaaaaa2", "subnet-0bbbbbbbbbbbbbbb2"])
    error_message = "Un endpoint por AZ."
  }

  assert {
    condition     = aws_networkfirewall_firewall.this.delete_protection
    error_message = "El firewall tiene protección contra borrado por defecto."
  }
}

run "routes_are_per_az" {
  command = plan

  assert {
    condition     = toset(keys(aws_route.private_to_firewall)) == toset(["us-east-1a", "us-east-1b"]) && toset(keys(aws_route.firewall_to_nat)) == toset(["us-east-1a", "us-east-1b"])
    error_message = "Cada AZ rutea al firewall y al NAT gateway de su propia AZ."
  }

  assert {
    condition     = alltrue([for r in aws_route.private_to_firewall : r.destination_cidr_block == "0.0.0.0/0"]) && alltrue([for r in aws_route.firewall_to_nat : r.destination_cidr_block == "0.0.0.0/0"])
    error_message = "La ruta por defecto va al firewall (privadas) y al NAT gateway (subnet del firewall)."
  }

  assert {
    condition     = toset(keys(aws_route.public_return_to_firewall)) == toset(["us-east-1a-10.0.0.0/20", "us-east-1b-10.0.0.0/20"])
    error_message = "La subnet pública devuelve el tráfico de retorno al firewall endpoint de su AZ."
  }
}

run "rejects_single_az" {
  command = plan

  variables {
    az_config = {
      "us-east-1a" = {
        public_subnet_id       = "subnet-0aaaaaaaaaaaaaaa1"
        firewall_subnet_id     = "subnet-0aaaaaaaaaaaaaaa2"
        private_route_table_id = "rtb-0aaaaaaaaaaaaaaa3"
        public_route_table_id  = "rtb-0aaaaaaaaaaaaaaa4"
      }
    }
  }

  expect_failures = [var.az_config]
}

run "rejects_empty_domain_list" {
  command = plan

  variables {
    allowed_domains = []
  }

  expect_failures = [var.allowed_domains]
}

run "logging_is_opt_in" {
  command = plan

  assert {
    condition     = length(aws_networkfirewall_logging_configuration.this) == 0
    error_message = "Sin alert_log_group_name no se crea la configuración de logging."
  }
}

run "logging_to_cloudwatch_when_requested" {
  command = plan

  variables {
    alert_log_group_name = "/aws/network-firewall/egress"
  }

  assert {
    condition     = [for d in aws_networkfirewall_logging_configuration.this[0].logging_configuration[0].log_destination_config : d.log_type] == ["ALERT"]
    error_message = "El logging envía los eventos ALERT."
  }
}
