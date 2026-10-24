# Tests sin credenciales ni recursos reales: mock_provider + command = plan.

mock_provider "google" {}

variables {
  project_id     = "demo-project"
  name           = "hub-test"
  firewall_zones = ["us-central1-a", "us-central1-b"]
  spokes = {
    app  = { cidr = "10.20.0.0/24" }
    data = { cidr = "10.30.0.0/24" }
  }
}

run "hub_exports_and_spokes_import_custom_routes" {
  command = plan

  assert {
    condition     = alltrue([for p in google_compute_network_peering.hub_to_spoke : p.export_custom_routes])
    error_message = "El hub tiene que exportar las custom routes (las rutas dinámicas no cruzan por defecto)."
  }

  assert {
    condition     = alltrue([for p in google_compute_network_peering.spoke_to_hub : p.import_custom_routes])
    error_message = "Cada spoke tiene que importar las custom routes del hub."
  }
}

run "every_spoke_is_peered_only_with_the_hub" {
  command = plan

  assert {
    condition     = toset(keys(google_compute_network_peering.hub_to_spoke)) == toset(["app", "data"]) && toset(keys(google_compute_network_peering.spoke_to_hub)) == toset(["app", "data"])
    error_message = "Cada spoke se peerea con el hub, y no con otros spokes."
  }
}

run "one_endpoint_per_zone_and_association_per_vpc_and_zone" {
  command = plan

  assert {
    condition     = toset(keys(google_network_security_firewall_endpoint.this)) == toset(var.firewall_zones)
    error_message = "Hace falta un firewall endpoint por zona."
  }

  assert {
    condition     = length(google_network_security_firewall_endpoint_association.this) == 6
    error_message = "Cada VPC (hub y dos spokes) se asocia al endpoint de cada zona: 3 x 2."
  }
}

run "no_policy_without_security_profile_group" {
  command = plan

  assert {
    condition     = length(google_compute_network_firewall_policy.inspection) == 0 && length(google_compute_network_firewall_policy_rule.egress) == 0
    error_message = "Sin perfil de seguridad no se crean la política ni las reglas."
  }
}

run "rules_apply_the_security_profile_group" {
  command = plan

  variables {
    security_profile_group = "organizations/123456789/locations/global/securityProfileGroups/example"
  }

  assert {
    condition     = google_compute_network_firewall_policy_rule.egress[0].action == "apply_security_profile_group" && google_compute_network_firewall_policy_rule.ingress[0].action == "apply_security_profile_group"
    error_message = "Las reglas tienen que usar la acción apply_security_profile_group."
  }

  assert {
    condition     = length(google_compute_network_firewall_policy_association.inspection) == 3
    error_message = "La política se asocia a cada VPC."
  }
}

run "rejects_empty_zones" {
  command = plan

  variables {
    firewall_zones = []
  }

  expect_failures = [var.firewall_zones]
}
