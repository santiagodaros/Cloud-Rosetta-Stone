# Salida a internet controlada — GCP
#
# Cloud NAT con IPs externas estáticas traduce la salida de las subnets, y una network firewall policy de Cloud NGFW
# deja salir por HTTPS solo a los FQDN permitidos: allow por FQDN y un deny de egress de menor prioridad.

locals {
  # En una firewall policy, 0 es la mayor prioridad.
  priority_allow_fqdns  = 1000
  priority_allow_ranges = 1100
  priority_deny_all     = 65000
}

# --- Cloud NAT con IPs fijas ----------------------------------------------------------------------

resource "google_compute_address" "nat" {
  count = var.nat_ip_count

  project = var.project_id
  name    = "${var.name}-nat-${count.index}"
  region  = var.region

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_router" "this" {
  project = var.project_id
  name    = "${var.name}-router"
  region  = var.region
  network = var.network_id
}

resource "google_compute_router_nat" "this" {
  project = var.project_id
  name    = "${var.name}-nat"
  router  = google_compute_router.this.name
  region  = var.region

  nat_ip_allocate_option             = "MANUAL_ONLY"
  nat_ips                            = google_compute_address.nat[*].self_link
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  # Asignación dinámica de puertos; no se puede combinar con endpoint-independent mapping
  # (gotcha: cloud-nat-ports-per-vm).
  enable_dynamic_port_allocation = true
  min_ports_per_vm               = var.min_ports_per_vm

  dynamic "subnetwork" {
    for_each = toset(var.subnetwork_self_links)
    content {
      name                    = subnetwork.value
      source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
    }
  }

  # Los paquetes descartados solo se registran con el logging de errores (gotcha: cloud-nat-ports-per-vm).
  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# --- Cloud NGFW: control de destinos (gotcha: egress-allowed-by-default) ------------------------------

resource "google_compute_network_firewall_policy" "this" {
  project     = var.project_id
  name        = "${var.name}-egress"
  description = "Salida a internet solo hacia los FQDN permitidos"
}

resource "google_compute_network_firewall_policy_association" "this" {
  project           = var.project_id
  name              = "${var.name}-egress"
  attachment_target = var.network_id
  firewall_policy   = google_compute_network_firewall_policy.this.id
}

# FQDN objects: se resuelven a IPs por DNS, sin comodines (gotcha: fqdn-objects-limits).
resource "google_compute_network_firewall_policy_rule" "allow_fqdns" {
  project         = var.project_id
  firewall_policy = google_compute_network_firewall_policy.this.name
  rule_name       = "allow-egress-fqdns"
  priority        = local.priority_allow_fqdns
  direction       = "EGRESS"
  action          = "allow"
  enable_logging  = true

  match {
    dest_fqdns = var.allowed_fqdns

    layer4_configs {
      ip_protocol = "tcp"
      ports       = ["443"]
    }
  }
}

resource "google_compute_network_firewall_policy_rule" "allow_ranges" {
  count = length(var.always_allowed_cidrs) > 0 ? 1 : 0

  project         = var.project_id
  firewall_policy = google_compute_network_firewall_policy.this.name
  rule_name       = "allow-egress-ranges"
  priority        = local.priority_allow_ranges
  direction       = "EGRESS"
  action          = "allow"
  enable_logging  = true

  match {
    dest_ip_ranges = var.always_allowed_cidrs

    layer4_configs {
      ip_protocol = "all"
    }
  }
}

# Sin este deny, la regla implícita de egress permite cualquier destino (gotcha: egress-allowed-by-default).
resource "google_compute_network_firewall_policy_rule" "deny_all" {
  project         = var.project_id
  firewall_policy = google_compute_network_firewall_policy.this.name
  rule_name       = "deny-egress-all"
  priority        = local.priority_deny_all
  direction       = "EGRESS"
  action          = "deny"
  enable_logging  = true

  match {
    dest_ip_ranges = ["0.0.0.0/0"]

    layer4_configs {
      ip_protocol = "all"
    }
  }
}
