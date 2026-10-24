# Tests sin credenciales ni recursos reales: mock_provider + command = plan.

mock_provider "google" {}

variables {
  project_id            = "demo-project"
  name                  = "egress-test"
  network_id            = "projects/demo-project/global/networks/hub"
  subnetwork_self_links = ["https://www.googleapis.com/compute/v1/projects/demo-project/regions/us-central1/subnetworks/workloads"]
  allowed_fqdns         = ["api.example.com", "updates.example.com"]
}

run "nat_uses_static_ips_and_dynamic_ports" {
  command = plan

  assert {
    condition     = google_compute_router_nat.this.nat_ip_allocate_option == "MANUAL_ONLY" && length(google_compute_address.nat) == 1
    error_message = "Cloud NAT tiene que usar IPs estáticas propias (las del allowlist)."
  }

  assert {
    condition     = google_compute_router_nat.this.enable_dynamic_port_allocation && google_compute_router_nat.this.min_ports_per_vm == 64
    error_message = "Asignación dinámica de puertos con el mínimo por VM configurado."
  }

  assert {
    condition     = google_compute_router_nat.this.log_config[0].enable && google_compute_router_nat.this.log_config[0].filter == "ERRORS_ONLY"
    error_message = "El logging de errores tiene que estar activo."
  }

  assert {
    condition     = google_compute_router_nat.this.source_subnetwork_ip_ranges_to_nat == "LIST_OF_SUBNETWORKS"
    error_message = "El NAT aplica solo a las subnets indicadas."
  }
}

run "allow_by_fqdn_then_deny_all" {
  command = plan

  assert {
    condition     = toset(google_compute_network_firewall_policy_rule.allow_fqdns.match[0].dest_fqdns) == toset(var.allowed_fqdns)
    error_message = "La regla allow tiene que apuntar a los FQDN permitidos."
  }

  assert {
    condition     = google_compute_network_firewall_policy_rule.allow_fqdns.direction == "EGRESS" && google_compute_network_firewall_policy_rule.allow_fqdns.action == "allow"
    error_message = "Los FQDN se permiten en egress."
  }

  assert {
    condition     = google_compute_network_firewall_policy_rule.deny_all.action == "deny" && google_compute_network_firewall_policy_rule.deny_all.priority > google_compute_network_firewall_policy_rule.allow_fqdns.priority
    error_message = "El deny de egress tiene que ser de menor prioridad (número más alto) que el allow."
  }
}

run "deny_all_covers_named_protocols" {
  command = plan

  assert {
    condition     = toset([for c in google_compute_network_firewall_policy_rule.deny_all.match[0].layer4_configs : c.ip_protocol]) == toset(["tcp", "udp", "icmp", "esp", "ah", "sctp", "ipip"])
    error_message = "El deny de egress enumera los protocolos que admite la API (no admite 'all')."
  }

  assert {
    condition     = !contains([for c in google_compute_network_firewall_policy_rule.deny_all.match[0].layer4_configs : c.ip_protocol], "all")
    error_message = "ipProtocol 'all' no está documentado en layer4Configs."
  }
}

run "ranges_rule_only_when_requested" {
  command = plan

  assert {
    condition     = length(google_compute_network_firewall_policy_rule.allow_ranges) == 0
    error_message = "Sin always_allowed_cidrs no hay regla de rangos."
  }
}

run "ranges_rule_is_created_with_cidrs" {
  command = plan

  variables {
    always_allowed_cidrs = ["10.0.0.0/8"]
  }

  assert {
    condition     = length(google_compute_network_firewall_policy_rule.allow_ranges) == 1 && google_compute_network_firewall_policy_rule.allow_ranges[0].priority < google_compute_network_firewall_policy_rule.deny_all.priority
    error_message = "Los rangos siempre permitidos se evalúan antes del deny."
  }
}

run "rejects_wildcard_fqdn" {
  command = plan

  variables {
    allowed_fqdns = ["*.example.com"]
  }

  expect_failures = [var.allowed_fqdns]
}

run "rejects_non_power_of_two_ports" {
  command = plan

  variables {
    min_ports_per_vm = 100
  }

  expect_failures = [var.min_ports_per_vm]
}
