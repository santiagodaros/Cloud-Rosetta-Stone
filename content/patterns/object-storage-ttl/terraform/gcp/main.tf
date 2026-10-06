# Ingesta privada de objetos con expiración (TTL) — GCP
#
# Bucket con UBLA + public access prevention, soft delete explícito,
# acceso desde una subnet con Private Google Access, escritura acotada
# a un prefijo con IAM Conditions y borrado a los N días.

# --- Red ----------------------------------------------------------------------

resource "google_compute_network" "this" {
  name                    = "vpc-${var.name}"
  auto_create_subnetworks = false
}

# Denegar todo ingress explícitamente (las VPCs custom no traen reglas,
# pero declararlo deja la intención en el código).
resource "google_compute_firewall" "deny_all_ingress" {
  name      = "fw-${var.name}-deny-all-ingress"
  network   = google_compute_network.this.id
  direction = "INGRESS"
  priority  = 65534

  deny {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_subnetwork" "workloads" {
  name          = "snet-${var.name}-workloads"
  region        = var.region
  network       = google_compute_network.this.id
  ip_cidr_range = var.subnet_cidr

  # VMs/servicios sin IP pública llegan a storage.googleapis.com sin NAT.
  # No restringe quién accede al bucket (gotcha: pga-is-not-a-perimeter).
  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# --- Bucket -------------------------------------------------------------------

resource "google_storage_bucket" "ingest" {
  #checkov:skip=CKV_GCP_62:Access logs fuera de alcance; usar Cloud Audit Logs (Data Access) si se requiere auditoría.
  #checkov:skip=CKV_GCP_78:Sin versioning a propósito: el TTL es el comportamiento buscado.
  name          = var.bucket_name
  location      = upper(var.region)
  storage_class = "STANDARD"
  force_destroy = false
  labels        = var.labels

  # Equivalente a BucketOwnerEnforced + Block Public Access (gotcha: ubla-and-pap).
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = false
  }

  # Default de GCS: 7 días. Acá es una decisión explícita (gotcha: soft-delete-default-7-days).
  soft_delete_policy {
    retention_duration_seconds = var.soft_delete_retention_seconds
  }

  lifecycle_rule {
    condition {
      age            = var.ttl_days
      matches_prefix = [var.object_prefix]
    }
    action {
      type = "Delete"
    }
  }

  lifecycle_rule {
    condition {
      age = 1
    }
    action {
      type = "AbortIncompleteMultipartUpload"
    }
  }

  dynamic "ip_filter" {
    for_each = var.restrict_to_vpc ? [1] : []
    content {
      mode = "Enabled"
      vpc_network_sources {
        network                = google_compute_network.this.id
        allowed_ip_cidr_ranges = [var.subnet_cidr]
      }
    }
  }
}

# --- Identidad del productor --------------------------------------------------

resource "google_service_account" "producer" {
  account_id   = "${var.name}-producer"
  display_name = "Productor de ingesta (${var.name})"
}

resource "google_storage_bucket_iam_member" "producer_create" {
  bucket = google_storage_bucket.ingest.name
  # objectCreator no puede sobrescribir (gotcha: objectcreator-cannot-overwrite).
  role   = "roles/storage.objectCreator"
  member = google_service_account.producer.member

  # Acotado al prefijo, como en S3. Requiere UBLA.
  condition {
    title       = "only-${trimsuffix(var.object_prefix, "/")}"
    description = "Solo objetos bajo ${var.object_prefix}"
    expression  = "resource.name.startsWith(\"projects/_/buckets/${var.bucket_name}/objects/${var.object_prefix}\")"
  }
}
