# DNS privado híbrido — GCP
#
# Inbound server policy (on-premises consulta las IPs que toma de cada subnet),
# forwarding zone privada para corp.example.com y el Cloud Router anunciando
# 35.199.192.0/19, el rango desde el que Cloud DNS envía las consultas reenviadas.

locals {
  # Origen de toda consulta que Cloud DNS reenvía: on-premises necesita la ruta de vuelta.
  cloud_dns_source_range = "35.199.192.0/19"
  onprem_fqdn            = "${trimsuffix(var.onprem_domain, ".")}."
  zone_fqdn              = "${trimsuffix(var.private_zone_name, ".")}."
}

resource "google_dns_policy" "inbound" {
  project                   = var.project_id
  name                      = "${var.name}-inbound"
  description               = "Permite que on-premises consulte las zonas privadas de esta VPC"
  enable_inbound_forwarding = true
  enable_logging            = true

  networks {
    network_url = var.network_id
  }
}

resource "google_dns_managed_zone" "onprem" {
  #checkov:skip=CKV_GCP_16:DNSSEC no aplica a una forwarding zone privada (las respuestas las da on-premises).
  project     = var.project_id
  name        = "${var.name}-onprem"
  dns_name    = local.onprem_fqdn
  description = "Reenvía ${var.onprem_domain} a los DNS on-premises"
  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = var.network_id
    }
  }

  forwarding_config {
    dynamic "target_name_servers" {
      for_each = var.onprem_dns_servers
      content {
        ipv4_address = target_name_servers.value
        # Siempre por la VPC, aunque el destino no sea RFC 1918 (gotcha: forwarding-path-private).
        forwarding_path = "private"
      }
    }
  }
}

resource "google_dns_managed_zone" "cloud" {
  #checkov:skip=CKV_GCP_16:DNSSEC no aplica a zonas privadas en Cloud DNS.
  project     = var.project_id
  name        = "${var.name}-cloud"
  dns_name    = local.zone_fqdn
  description = "Zona privada resoluble desde on-premises vía la inbound policy"
  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = var.network_id
    }
  }
}

# Sin este anuncio, on-premises recibe la consulta pero la respuesta no vuelve
# (gotcha: return-route-35-199-192-0-19).
resource "google_compute_router" "hybrid" {
  project = var.project_id
  name    = "${var.name}-router"
  region  = var.region
  network = var.network_id

  bgp {
    asn               = var.router_asn
    advertise_mode    = "CUSTOM"
    advertised_groups = ["ALL_SUBNETS"]

    advertised_ip_ranges {
      range       = local.cloud_dns_source_range
      description = "Origen de las consultas reenviadas por Cloud DNS"
    }
  }
}
