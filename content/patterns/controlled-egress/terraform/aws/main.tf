# Salida a internet controlada — AWS
#
# Cadena por AZ: subnet privada -> firewall endpoint (Network Firewall) -> NAT gateway (subnet pública) -> internet
# gateway. Un NAT gateway y un firewall endpoint por AZ, y cada subnet rutea al de su propia AZ.

locals {
  azs = keys(var.az_config)

  # Endpoint de cada AZ; la clave es el nombre de la AZ, igual que en az_config.
  endpoint_by_az = {
    for s in aws_networkfirewall_firewall.this.firewall_status[0].sync_states :
    s.availability_zone => s.attachment[0].endpoint_id
  }

  # Ruta de retorno: el tráfico hacia las subnets privadas vuelve por el firewall endpoint de la misma AZ.
  return_routes = {
    for pair in setproduct(local.azs, var.private_cidrs) :
    "${pair[0]}-${pair[1]}" => { az = pair[0], cidr = pair[1] }
  }
}

# --- NAT gateways: uno por AZ (gotcha: nat-zonal-single-az) ------------------------------------

resource "aws_eip" "nat" {
  for_each = var.az_config

  domain = "vpc"

  tags = {
    Name = "${var.name}-nat-${each.key}"
  }
}

resource "aws_nat_gateway" "this" {
  for_each = var.az_config

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = each.value.public_subnet_id

  tags = {
    Name = "${var.name}-${each.key}"
  }
}

# --- Network Firewall: lista de dominios (gotcha: network-firewall-domain-list) ------------------------

resource "aws_networkfirewall_rule_group" "domains" {
  #checkov:skip=CKV_AWS_345:El módulo no crea ni recibe una KMS key; las reglas no contienen datos de cliente y se cifran con la clave propiedad de AWS (por defecto). Para exigir CMK hay que agregar encryption_configuration con una key propia.
  name     = "${var.name}-allowed-domains"
  type     = "STATEFUL"
  capacity = var.rule_group_capacity

  rule_group {
    # HOME_NET: por defecto es solo el CIDR de la VPC del firewall (gotcha: network-firewall-domain-list).
    rule_variables {
      ip_sets {
        key = "HOME_NET"
        ip_set {
          definition = var.private_cidrs
        }
      }
    }

    rules_source {
      rules_source_list {
        generated_rules_type = "ALLOWLIST"
        target_types         = ["HTTP_HOST", "TLS_SNI"]
        targets              = var.allowed_domains
      }
    }
  }
}

# Default action order: con strict order la denegación de lo que no coincide no aplica
# (gotcha: network-firewall-domain-list).
resource "aws_networkfirewall_firewall_policy" "this" {
  #checkov:skip=CKV_AWS_346:El módulo no crea ni recibe una KMS key; las reglas no contienen datos de cliente y se cifran con la clave propiedad de AWS (por defecto). Para exigir CMK hay que agregar encryption_configuration con una key propia.
  name = "${var.name}-egress"

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]

    stateful_engine_options {
      rule_order = "DEFAULT_ACTION_ORDER"
    }

    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.domains.arn
    }
  }
}

resource "aws_networkfirewall_firewall" "this" {
  #checkov:skip=CKV_AWS_345:El módulo no crea ni recibe una KMS key; las reglas no contienen datos de cliente y se cifran con la clave propiedad de AWS (por defecto). Para exigir CMK hay que agregar encryption_configuration con una key propia.
  name                = var.name
  vpc_id              = var.vpc_id
  firewall_policy_arn = aws_networkfirewall_firewall_policy.this.arn
  delete_protection   = var.delete_protection

  dynamic "subnet_mapping" {
    for_each = var.az_config
    content {
      subnet_id = subnet_mapping.value.firewall_subnet_id
    }
  }
}

# Logs de alertas a CloudWatch Logs (opcional: el log group es de la cuenta, no lo crea el módulo).
resource "aws_networkfirewall_logging_configuration" "this" {
  count = var.alert_log_group_name == null ? 0 : 1

  firewall_arn = aws_networkfirewall_firewall.this.arn

  logging_configuration {
    log_destination_config {
      log_destination      = { logGroup = var.alert_log_group_name }
      log_destination_type = "CloudWatchLogs"
      log_type             = "ALERT"
    }
  }
}

# --- Rutas ------------------------------------------------------------------------------------------

# Subnets privadas -> firewall endpoint de su AZ.
resource "aws_route" "private_to_firewall" {
  for_each = var.az_config

  route_table_id         = each.value.private_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = try(local.endpoint_by_az[each.key], null)
}

# Subnet del firewall -> NAT gateway de su AZ.
resource "aws_route_table" "firewall" {
  for_each = var.az_config

  vpc_id = var.vpc_id

  tags = {
    Name = "${var.name}-firewall-${each.key}"
  }
}

resource "aws_route" "firewall_to_nat" {
  for_each = var.az_config

  route_table_id         = aws_route_table.firewall[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[each.key].id
}

resource "aws_route_table_association" "firewall" {
  for_each = var.az_config

  subnet_id      = each.value.firewall_subnet_id
  route_table_id = aws_route_table.firewall[each.key].id
}

# Subnet pública -> de vuelta al firewall endpoint, para que la respuesta no salte la inspección.
resource "aws_route" "public_return_to_firewall" {
  for_each = local.return_routes

  route_table_id         = var.az_config[each.value.az].public_route_table_id
  destination_cidr_block = each.value.cidr
  vpc_endpoint_id        = try(local.endpoint_by_az[each.value.az], null)
}
