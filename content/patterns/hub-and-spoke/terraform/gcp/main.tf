# Hub-and-spoke con inspección centralizada — GCP
#
# VPC hub peereada con cada spoke (el hub exporta custom routes, los spokes las importan) y
# Cloud NGFW: un firewall endpoint zonal por zona, asociado a cada VPC, más una política
# de firewall que manda el tráfico seleccionado al perfil de seguridad.

locals {
  # Todas las VPC del patrón, hub incluido: cada una se asocia a los endpoints.
  networks = merge({ hub = var.hub_cidr }, { for k, v in var.spokes : k => v.cidr })

  # Un par (zona, VPC) por asociación.
  associations = {
    for pair in setproduct(var.firewall_zones, keys(local.networks)) :
    "${pair[0]}|${pair[1]}" => { zone = pair[0], network = pair[1] }
  }

  inspect = var.security_profile_group != null
}

resource "google_compute_network" "this" {
  for_each = local.networks

  project                 = var.project_id
  name                    = "${var.name}-${each.key}"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "this" {
  for_each = local.networks

  project       = var.project_id
  name          = "${var.name}-${each.key}"
  region        = var.region
  network       = google_compute_network.this[each.key].id
  ip_cidr_range = each.value

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# El peering no es transitivo: dos spokes no se ven a través del hub
# (gotcha: peering-not-transitive-no-spoke-to-spoke). Las custom routes no cruzan salvo
# que el hub las exporte y el spoke las importe (gotcha: peering-custom-routes-off-by-default).
resource "google_compute_network_peering" "hub_to_spoke" {
  for_each = var.spokes

  name                 = "${var.name}-hub-to-${each.key}"
  network              = google_compute_network.this["hub"].self_link
  peer_network         = google_compute_network.this[each.key].self_link
  export_custom_routes = true
}

resource "google_compute_network_peering" "spoke_to_hub" {
  for_each = var.spokes

  name                 = "${var.name}-${each.key}-to-hub"
  network              = google_compute_network.this[each.key].self_link
  peer_network         = google_compute_network.this["hub"].self_link
  import_custom_routes = true

  # Los dos lados se crean en serie para evitar conflictos de operaciones sobre la red.
  depends_on = [google_compute_network_peering.hub_to_spoke]
}

# --- Cloud NGFW --------------------------------------------------------------------

# Zonal: hace falta uno por zona donde corran workloads (gotcha: firewall-endpoint-zonal-per-vpc).
resource "google_network_security_firewall_endpoint" "this" {
  for_each = toset(var.firewall_zones)

  name     = "${var.name}-${each.key}"
  parent   = "projects/${var.project_id}"
  location = each.key
}

resource "google_network_security_firewall_endpoint_association" "this" {
  for_each = local.associations

  name              = "${var.name}-${each.value.network}-${each.value.zone}"
  parent            = "projects/${var.project_id}"
  location          = each.value.zone
  network           = google_compute_network.this[each.value.network].id
  firewall_endpoint = google_network_security_firewall_endpoint.this[each.value.zone].id
}

# Sin una regla con apply_security_profile_group el tráfico no llega al endpoint.
resource "google_compute_network_firewall_policy" "inspection" {
  count = local.inspect ? 1 : 0

  project     = var.project_id
  name        = "${var.name}-inspection"
  description = "Manda el tráfico seleccionado al perfil de seguridad de Cloud NGFW"
}

resource "google_compute_network_firewall_policy_association" "inspection" {
  for_each = local.inspect ? local.networks : {}

  project           = var.project_id
  name              = "${var.name}-${each.key}"
  attachment_target = google_compute_network.this[each.key].id
  firewall_policy   = google_compute_network_firewall_policy.inspection[0].id
}

resource "google_compute_network_firewall_policy_rule" "egress" {
  count = local.inspect ? 1 : 0

  project                = var.project_id
  firewall_policy        = google_compute_network_firewall_policy.inspection[0].name
  rule_name              = "inspect-egress"
  priority               = 1000
  direction              = "EGRESS"
  action                 = "apply_security_profile_group"
  security_profile_group = var.security_profile_group
  enable_logging         = true

  match {
    dest_ip_ranges = var.inspected_cidrs

    layer4_configs {
      ip_protocol = "all"
    }
  }
}

resource "google_compute_network_firewall_policy_rule" "ingress" {
  count = local.inspect ? 1 : 0

  project                = var.project_id
  firewall_policy        = google_compute_network_firewall_policy.inspection[0].name
  rule_name              = "inspect-ingress"
  priority               = 1001
  direction              = "INGRESS"
  action                 = "apply_security_profile_group"
  security_profile_group = var.security_profile_group
  enable_logging         = true

  match {
    src_ip_ranges = var.inspected_cidrs

    layer4_configs {
      ip_protocol = "all"
    }
  }
}
