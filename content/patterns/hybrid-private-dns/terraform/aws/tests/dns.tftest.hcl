# Tests sin credenciales ni recursos reales: mock_provider + command = plan.

mock_provider "aws" {}

variables {
  name                = "dns-test"
  vpc_id              = "vpc-0123456789abcdef0"
  endpoint_subnet_ids = ["subnet-0aaaaaaaaaaaaaaa1", "subnet-0bbbbbbbbbbbbbbb2"]
  onprem_cidrs        = ["192.168.0.0/16"]
  onprem_dns_servers  = ["192.168.10.10", "192.168.10.11"]
  spoke_vpc_ids       = { app = "vpc-0fedcba9876543210" }
}

run "endpoint_directions" {
  command = plan

  assert {
    condition     = aws_route53_resolver_endpoint.inbound.direction == "INBOUND" && aws_route53_resolver_endpoint.outbound.direction == "OUTBOUND"
    error_message = "Direcciones de los endpoints invertidas."
  }
}

run "dns_allows_udp_and_tcp" {
  command = plan

  assert {
    condition     = toset([for r in aws_vpc_security_group_ingress_rule.dns_from_onprem : r.ip_protocol]) == toset(["udp", "tcp"])
    error_message = "El security group tiene que permitir UDP y TCP 53."
  }
}

run "forward_rule_associated_to_hub_and_spokes" {
  command = plan

  assert {
    condition     = aws_route53_resolver_rule.onprem.rule_type == "FORWARD" && length(aws_route53_resolver_rule.onprem.target_ip) == 2
    error_message = "La regla tiene que ser FORWARD hacia los DNS on-premises."
  }

  assert {
    condition     = toset(keys(aws_route53_resolver_rule_association.this)) == toset(["hub", "app"])
    error_message = "La regla se asocia a cada VPC que la necesita."
  }
}

run "private_zone_in_inbound_vpc" {
  command = plan

  assert {
    condition     = one(aws_route53_zone.cloud.vpc).vpc_id == var.vpc_id
    error_message = "La private hosted zone tiene que estar asociada a la VPC del inbound endpoint."
  }
}

run "rejects_single_subnet" {
  command = plan

  variables {
    endpoint_subnet_ids = ["subnet-0aaaaaaaaaaaaaaa1"]
  }

  expect_failures = [var.endpoint_subnet_ids]
}
