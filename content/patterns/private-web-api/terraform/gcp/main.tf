# Web API privada Zero Trust — GCP
#
# Cloud Run con ingress interno e IAM invoker, saliendo por Direct VPC egress
# hacia Cloud SQL for PostgreSQL con IP privada (PSA) y autenticación IAM.

# --- Red ----------------------------------------------------------------------

resource "google_compute_network" "this" {
  name                    = "vpc-${var.name}"
  auto_create_subnetworks = false
}

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

resource "google_compute_subnetwork" "run" {
  name                     = "snet-${var.name}-run"
  region                   = var.region
  network                  = google_compute_network.this.id
  ip_cidr_range            = var.subnet_cidr
  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# Private services access: peering hacia la red de Google (gotcha: psa-peering-not-transitive).
resource "google_compute_global_address" "psa" {
  name          = "psa-${var.name}"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = var.psa_prefix_length
  network       = google_compute_network.this.id
}

resource "google_service_networking_connection" "psa" {
  network                 = google_compute_network.this.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.psa.name]
}

# --- Cloud SQL (solo IP privada, IAM auth, connectors obligatorios) -----------

resource "google_sql_database_instance" "this" {
  #checkov:skip=CKV_GCP_110:pgAudit agrega volumen y costo de logs; habilitar si hay requisito de auditoría.
  #checkov:skip=CKV_GCP_79:Major version alineada entre las tres nubes del patrón (PostgreSQL 17); se sube en conjunto.
  #checkov:skip=CKV2_GCP_13:log_duration en todas las sentencias es ruidoso; se usa log_min_duration_statement.
  name                = "pg-${var.name}"
  region              = var.region
  database_version    = "POSTGRES_17"
  deletion_protection = var.deletion_protection

  settings {
    edition           = "ENTERPRISE"
    tier              = var.db_tier
    availability_type = "ZONAL"

    # Solo connectors (Auth Proxy / Language Connectors) — gotcha: connector-enforcement.
    connector_enforcement = "REQUIRED"

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.this.id
      # Los connectors usan mTLS con certificados efímeros, así que se puede exigir
      # certificado de cliente sin distribuir certificados a mano.
      ssl_mode = "TRUSTED_CLIENT_CERTIFICATE_REQUIRED"
    }

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
    }

    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }
    database_flags {
      name  = "log_connections"
      value = "on"
    }
    database_flags {
      name  = "log_disconnections"
      value = "on"
    }
    database_flags {
      name  = "log_checkpoints"
      value = "on"
    }
    database_flags {
      name  = "log_lock_waits"
      value = "on"
    }
    database_flags {
      name  = "log_temp_files"
      value = "0"
    }
    database_flags {
      name  = "log_min_duration_statement"
      value = "-1"
    }
    database_flags {
      name  = "log_hostname"
      value = "on"
    }
    database_flags {
      name  = "log_min_messages"
      value = "error"
    }
    database_flags {
      name  = "log_min_error_statement"
      value = "error"
    }
    database_flags {
      name  = "log_statement"
      value = "ddl"
    }

    user_labels = var.labels
  }

  depends_on = [google_service_networking_connection.psa]
}

resource "google_sql_database" "app" {
  name     = var.database_name
  instance = google_sql_database_instance.this.name
}

# --- Identidad de la API --------------------------------------------------------

resource "google_service_account" "api" {
  account_id   = "${var.name}-api"
  display_name = "API privada (${var.name})"
}

resource "google_project_iam_member" "api" {
  for_each = toset(["roles/cloudsql.client", "roles/cloudsql.instanceUser"])
  project  = var.project_id
  role     = each.value
  member   = google_service_account.api.member
}

# Login IAM creado por API, sin SQL. El nombre va SIN ".gserviceaccount.com"
# (gotchas: iam-sa-username-trim, iam-user-created-by-api).
resource "google_sql_user" "api" {
  name     = trimsuffix(google_service_account.api.email, ".gserviceaccount.com")
  instance = google_sql_database_instance.this.name
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
}

# --- Cloud Run (ingress interno + IAM invoker) --------------------------------

resource "google_cloud_run_v2_service" "api" {
  name                = "${var.name}-api"
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_INTERNAL_ONLY"
  deletion_protection = var.deletion_protection
  labels              = var.labels

  template {
    service_account = google_service_account.api.email

    scaling {
      min_instance_count = 0
      max_instance_count = var.max_instances
    }

    vpc_access {
      egress = "PRIVATE_RANGES_ONLY"
      network_interfaces {
        network    = google_compute_network.this.id
        subnetwork = google_compute_subnetwork.run.id
      }
    }

    containers {
      image = var.container_image

      ports {
        container_port = var.container_port
      }

      # La app usa el Cloud SQL Language Connector con IAM auth automática:
      # no hay contraseña ni token manual.
      env {
        name  = "INSTANCE_CONNECTION_NAME"
        value = google_sql_database_instance.this.connection_name
      }
      env {
        name  = "DB_IAM_USER"
        value = google_sql_user.api.name
      }
      env {
        name  = "DB_NAME"
        value = var.database_name
      }
      env {
        name  = "DB_IP_TYPE"
        value = "PRIVATE"
      }
    }
  }
}

# Sin allUsers: cada caller necesita roles/run.invoker (validado en la variable).
resource "google_cloud_run_v2_service_iam_member" "invoker" {
  for_each = var.invoker_members
  name     = google_cloud_run_v2_service.api.name
  location = google_cloud_run_v2_service.api.location
  role     = "roles/run.invoker"
  member   = each.value
}
