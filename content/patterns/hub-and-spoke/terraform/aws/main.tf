# Hub-and-spoke con inspección centralizada — AWS
#
# Transit Gateway sin asociación ni propagación por defecto, VPC de inspección con un
# Network Firewall endpoint por AZ, y route tables propias: los spokes mandan 0.0.0.0/0 al
# attachment de inspección y la inspección recibe las rutas propagadas de los spokes.

locals {
  # Un índice por AZ para derivar los CIDR de las subnets.
  az_index = { for i, az in var.azs : az => i }

  # Endpoint de cada AZ; se conoce después del apply.
  endpoint_by_az = try(
    { for s in aws_networkfirewall_firewall.this.firewall_status[0].sync_states : s.availability_zone => s.attachment[0].endpoint_id },
    {}
  )
}

# --- Transit Gateway ---------------------------------------------------------------

# Con la route table por defecto todos los attachments se ven entre sí y la inspección no
# corre (gotcha: default-route-table-bypasses-inspection).
resource "aws_ec2_transit_gateway" "this" {
  description                     = "${var.name} hub"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  auto_accept_shared_attachments  = "disable"
  tags                            = { Name = var.name }
}

resource "aws_ec2_transit_gateway_route_table" "spokes" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  tags               = { Name = "${var.name}-spokes" }
}

resource "aws_ec2_transit_gateway_route_table" "inspection" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  tags               = { Name = "${var.name}-inspection" }
}

# --- VPC de inspección -------------------------------------------------------------

resource "aws_vpc" "inspection" {
  #checkov:skip=CKV2_AWS_11:Los flow logs de la VPC de inspección se configuran con el logging centralizado del hub, fuera del alcance del patrón.
  cidr_block = var.inspection_vpc_cidr
  tags       = { Name = "${var.name}-inspection" }
}

resource "aws_default_security_group" "inspection" {
  vpc_id = aws_vpc.inspection.id
  tags   = { Name = "${var.name}-inspection-default" }
}

# Subnets del attachment: una por AZ (gotcha: attachment-az-coverage).
resource "aws_subnet" "tgw" {
  for_each = local.az_index

  vpc_id            = aws_vpc.inspection.id
  availability_zone = each.key
  cidr_block        = cidrsubnet(var.inspection_vpc_cidr, 8, each.value)
  tags              = { Name = "${var.name}-tgw-${each.key}" }
}

# Subnets exclusivas del firewall: un endpoint no filtra el tráfico de su propia subnet
# (gotcha: firewall-subnet-dedicated-same-az).
resource "aws_subnet" "firewall" {
  for_each = local.az_index

  vpc_id            = aws_vpc.inspection.id
  availability_zone = each.key
  cidr_block        = cidrsubnet(var.inspection_vpc_cidr, 8, 100 + each.value)
  tags              = { Name = "${var.name}-firewall-${each.key}" }
}

# Appliance mode: ida y vuelta por la misma AZ (gotcha: appliance-mode-for-symmetric-inspection).
resource "aws_ec2_transit_gateway_vpc_attachment" "inspection" {
  transit_gateway_id     = aws_ec2_transit_gateway.this.id
  vpc_id                 = aws_vpc.inspection.id
  subnet_ids             = [for s in aws_subnet.tgw : s.id]
  appliance_mode_support = "enable"

  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = { Name = "${var.name}-inspection" }
}

resource "aws_ec2_transit_gateway_route_table_association" "inspection" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.inspection.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.inspection.id
}

# --- Network Firewall --------------------------------------------------------------

resource "aws_networkfirewall_rule_group" "egress_domains" {
  count = length(var.allowed_egress_domains) > 0 ? 1 : 0

  name     = "${var.name}-egress-domains"
  capacity = 100
  type     = "STATEFUL"

  rule_group {
    rules_source {
      rules_source_list {
        generated_rules_type = "ALLOWLIST"
        target_types         = ["HTTP_HOST", "TLS_SNI"]
        targets              = var.allowed_egress_domains
      }
    }
  }
}

resource "aws_networkfirewall_firewall_policy" "this" {
  name = var.name

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]

    dynamic "stateful_rule_group_reference" {
      for_each = aws_networkfirewall_rule_group.egress_domains
      content {
        resource_arn = stateful_rule_group_reference.value.arn
      }
    }
  }
}

# Un endpoint por subnet de firewall, es decir, uno por AZ; cada uno se factura por hora
# (gotcha: tgw-and-firewall-hourly-charges).
resource "aws_networkfirewall_firewall" "this" {
  name                = var.name
  firewall_policy_arn = aws_networkfirewall_firewall_policy.this.arn
  vpc_id              = aws_vpc.inspection.id

  dynamic "subnet_mapping" {
    for_each = aws_subnet.firewall
    content {
      subnet_id = subnet_mapping.value.id
    }
  }
}

# Subnet del attachment -> endpoint de la misma AZ; subnet del firewall -> Transit Gateway.
resource "aws_route_table" "tgw" {
  for_each = local.az_index

  vpc_id = aws_vpc.inspection.id
  tags   = { Name = "${var.name}-tgw-${each.key}" }
}

resource "aws_route" "tgw_to_firewall" {
  for_each = local.az_index

  route_table_id         = aws_route_table.tgw[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = lookup(local.endpoint_by_az, each.key, null)
}

resource "aws_route_table_association" "tgw" {
  for_each = local.az_index

  subnet_id      = aws_subnet.tgw[each.key].id
  route_table_id = aws_route_table.tgw[each.key].id
}

resource "aws_route_table" "firewall" {
  vpc_id = aws_vpc.inspection.id
  tags   = { Name = "${var.name}-firewall" }
}

resource "aws_route" "firewall_to_tgw" {
  route_table_id         = aws_route_table.firewall.id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = aws_ec2_transit_gateway.this.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.inspection]
}

resource "aws_route_table_association" "firewall" {
  for_each = local.az_index

  subnet_id      = aws_subnet.firewall[each.key].id
  route_table_id = aws_route_table.firewall.id
}

# --- Spokes ----------------------------------------------------------------------

resource "aws_ec2_transit_gateway_vpc_attachment" "spoke" {
  for_each = var.spokes

  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id             = each.value.vpc_id
  subnet_ids         = each.value.subnet_ids

  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = { Name = "${var.name}-${each.key}" }
}

resource "aws_ec2_transit_gateway_route_table_association" "spoke" {
  for_each = var.spokes

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke[each.key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spokes.id
}

# La inspección recibe las rutas de los spokes para devolver el tráfico ya filtrado.
resource "aws_ec2_transit_gateway_route_table_propagation" "spoke_to_inspection" {
  for_each = var.spokes

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke[each.key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.inspection.id
}

# Todo lo que sale de un spoke va al attachment de inspección.
resource "aws_ec2_transit_gateway_route" "spokes_default_to_inspection" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.inspection.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spokes.id
}
