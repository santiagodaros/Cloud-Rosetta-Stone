# Tests sin credenciales ni recursos reales: mock_provider + command = plan.

mock_provider "aws" {}

variables {
  name = "hub-test"
  azs  = ["us-east-1a", "us-east-1b"]
  spokes = {
    app = {
      vpc_id     = "vpc-0aaaaaaaaaaaaaaa1"
      subnet_ids = ["subnet-0aaaaaaaaaaaaaaa1", "subnet-0aaaaaaaaaaaaaaa2"]
    }
    data = {
      vpc_id     = "vpc-0bbbbbbbbbbbbbbb2"
      subnet_ids = ["subnet-0bbbbbbbbbbbbbbb1", "subnet-0bbbbbbbbbbbbbbb2"]
    }
  }
}

run "default_route_table_is_disabled" {
  command = plan

  assert {
    condition     = aws_ec2_transit_gateway.this.default_route_table_association == "disable" && aws_ec2_transit_gateway.this.default_route_table_propagation == "disable"
    error_message = "Con la route table por defecto los spokes se ven entre sí sin pasar por el firewall."
  }

  assert {
    condition     = alltrue([for a in aws_ec2_transit_gateway_vpc_attachment.spoke : a.transit_gateway_default_route_table_association == false && a.transit_gateway_default_route_table_propagation == false])
    error_message = "Los attachments de los spokes no pueden usar la asociación ni la propagación por defecto."
  }
}

run "inspection_attachment_uses_appliance_mode" {
  command = plan

  assert {
    condition     = aws_ec2_transit_gateway_vpc_attachment.inspection.appliance_mode_support == "enable"
    error_message = "El attachment de inspección necesita appliance mode para que ida y vuelta pasen por la misma AZ."
  }

  assert {
    condition     = length(aws_subnet.tgw) == 2
    error_message = "El attachment de inspección tiene una subnet por AZ."
  }
}

run "spokes_default_route_goes_to_inspection" {
  command = plan

  assert {
    condition     = aws_ec2_transit_gateway_route.spokes_default_to_inspection.destination_cidr_block == "0.0.0.0/0"
    error_message = "Los spokes mandan 0.0.0.0/0 al attachment de inspección."
  }

  assert {
    condition     = toset(keys(aws_ec2_transit_gateway_route_table_association.spoke)) == toset(["app", "data"]) && toset(keys(aws_ec2_transit_gateway_route_table_propagation.spoke_to_inspection)) == toset(["app", "data"])
    error_message = "Cada spoke se asocia a la route table de spokes y propaga a la de inspección."
  }
}

run "one_firewall_endpoint_and_route_table_per_az" {
  command = plan

  assert {
    condition     = length(aws_subnet.firewall) == 2 && toset(keys(aws_route_table.tgw)) == toset(var.azs)
    error_message = "Hace falta un endpoint y una route table de attachment por AZ."
  }

  assert {
    condition     = alltrue([for r in aws_route.tgw_to_firewall : r.destination_cidr_block == "0.0.0.0/0"])
    error_message = "Las subnets del attachment mandan todo al firewall endpoint."
  }
}

run "domain_rule_group_only_when_requested" {
  command = plan

  assert {
    condition     = length(aws_networkfirewall_rule_group.egress_domains) == 0
    error_message = "Sin dominios no se crea el rule group."
  }
}

run "domain_rule_group_when_requested" {
  command = plan

  variables {
    allowed_egress_domains = [".example.com"]
  }

  assert {
    condition     = length(aws_networkfirewall_rule_group.egress_domains) == 1
    error_message = "Con dominios tiene que haber un rule group stateful."
  }
}

run "rejects_single_az" {
  command = plan

  variables {
    azs = ["us-east-1a"]
  }

  expect_failures = [var.azs]
}
