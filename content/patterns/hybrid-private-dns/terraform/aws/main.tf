# DNS privado híbrido — AWS
#
# Route 53 Resolver en la VPC hub: inbound endpoint para on-premises, outbound
# endpoint + regla FORWARD para corp.example.com, y la private hosted zone
# asociada a la VPC del inbound endpoint.

locals {
  # TCP además de UDP: respuestas grandes (DNSSEC, muchos registros) caen a TCP.
  dns_protocols = ["udp", "tcp"]
}

resource "aws_security_group" "resolver" {
  name        = "${var.name}-resolver"
  description = "Route 53 Resolver endpoints: DNS desde y hacia on-premises"
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "dns_from_onprem" {
  for_each = { for pair in setproduct(var.onprem_cidrs, local.dns_protocols) : "${pair[0]}-${pair[1]}" => pair }

  security_group_id = aws_security_group.resolver.id
  description       = "DNS desde on-premises (${each.value[1]})"
  cidr_ipv4         = each.value[0]
  ip_protocol       = each.value[1]
  from_port         = 53
  to_port           = 53
}

resource "aws_vpc_security_group_egress_rule" "dns_to_onprem" {
  for_each = { for pair in setproduct(var.onprem_cidrs, local.dns_protocols) : "${pair[0]}-${pair[1]}" => pair }

  security_group_id = aws_security_group.resolver.id
  description       = "DNS hacia on-premises (${each.value[1]})"
  cidr_ipv4         = each.value[0]
  ip_protocol       = each.value[1]
  from_port         = 53
  to_port           = 53
}

# Cada IP es una ENI que se cobra por hora (gotcha: resolver-endpoints-fixed-cost).
resource "aws_route53_resolver_endpoint" "inbound" {
  name               = "${var.name}-inbound"
  direction          = "INBOUND"
  security_group_ids = [aws_security_group.resolver.id]

  dynamic "ip_address" {
    for_each = var.endpoint_subnet_ids
    content {
      subnet_id = ip_address.value
    }
  }
}

resource "aws_route53_resolver_endpoint" "outbound" {
  name               = "${var.name}-outbound"
  direction          = "OUTBOUND"
  security_group_ids = [aws_security_group.resolver.id]

  dynamic "ip_address" {
    for_each = var.endpoint_subnet_ids
    content {
      subnet_id = ip_address.value
    }
  }
}

resource "aws_route53_resolver_rule" "onprem" {
  name                 = "${var.name}-onprem"
  domain_name          = var.onprem_domain
  rule_type            = "FORWARD"
  resolver_endpoint_id = aws_route53_resolver_endpoint.outbound.id

  dynamic "target_ip" {
    for_each = var.onprem_dns_servers
    content {
      ip   = target_ip.value
      port = 53
    }
  }
}

resource "aws_route53_resolver_rule_association" "this" {
  for_each = merge({ hub = var.vpc_id }, var.spoke_vpc_ids)

  name             = "${var.name}-${each.key}"
  resolver_rule_id = aws_route53_resolver_rule.onprem.id
  vpc_id           = each.value
}

# Tiene que estar asociada a la VPC del inbound endpoint para que on-premises la resuelva.
resource "aws_route53_zone" "cloud" {
  #checkov:skip=CKV2_AWS_38:DNSSEC signing no aplica a private hosted zones.
  #checkov:skip=CKV2_AWS_39:El query logging se configura a nivel VPC (Resolver query logging), fuera del alcance del patrón.
  name = var.private_zone_name

  vpc {
    vpc_id = var.vpc_id
  }
}
