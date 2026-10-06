# Tests sin credenciales ni recursos reales: mock_provider + command = plan.

mock_provider "google" {}

variables {
  project_id         = "demo-project"
  name               = "dns-test"
  network_id         = "projects/demo-project/global/networks/hub"
  onprem_dns_servers = ["192.168.10.10", "192.168.10.11"]
}

run "inbound_policy_enabled" {
  command = plan

  assert {
    condition     = google_dns_policy.inbound.enable_inbound_forwarding
    error_message = "La server policy tiene que habilitar inbound forwarding."
  }
}

run "forwarding_zone_goes_through_the_vpc" {
  command = plan

  assert {
    condition     = google_dns_managed_zone.onprem.dns_name == "corp.example.com." && google_dns_managed_zone.onprem.visibility == "private"
    error_message = "La forwarding zone tiene que ser privada y terminar en punto."
  }

  assert {
    condition     = alltrue([for t in google_dns_managed_zone.onprem.forwarding_config[0].target_name_servers : t.forwarding_path == "private"])
    error_message = "El reenvío a on-premises tiene que ir siempre por la VPC (forwarding_path = private)."
  }
}

run "router_advertises_cloud_dns_range" {
  command = plan

  assert {
    condition     = google_compute_router.hybrid.bgp[0].advertise_mode == "CUSTOM" && contains([for r in google_compute_router.hybrid.bgp[0].advertised_ip_ranges : r.range], "35.199.192.0/19")
    error_message = "El Cloud Router tiene que anunciar 35.199.192.0/19 para que vuelvan las respuestas."
  }

  assert {
    condition     = contains(google_compute_router.hybrid.bgp[0].advertised_groups, "ALL_SUBNETS")
    error_message = "En modo CUSTOM hay que seguir anunciando las subnets."
  }
}
