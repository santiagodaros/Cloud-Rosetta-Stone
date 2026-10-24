# Secretos de aplicación — GCP
#
# Secret Manager con CMEK de Cloud KMS, leído por una service account con acceso a nivel de secreto, desde una
# subnet con Private Google Access, y con los accesos auditados.
#
# El módulo NO crea ninguna versión: un google_secret_manager_secret_version dejaría el valor en el state de
# Terraform. Cargá la primera versión fuera de banda y configurá la app con el número de versión.
#
# Requisitos previos: API de Secret Manager y de Cloud KMS habilitadas, y el service agent de Secret Manager creado
# (gcloud beta services identity create --service secretmanager.googleapis.com).

data "google_project" "this" {
  project_id = var.project_id
}

locals {
  secret_manager_agent = "serviceAccount:service-${data.google_project.this.number}@gcp-sa-secretmanager.iam.gserviceaccount.com"
}

# --- Red: acceso privado a las APIs de Google ---------------------------------------

resource "google_compute_network" "workload" {
  name                    = "${var.name}-vpc"
  auto_create_subnetworks = false
}

# Flag por subnet. Solo sirve a VMs sin IP externa y no cubre los endpoints regionales *.rep.googleapis.com
# (gotcha: pga-skips-regional-endpoints).
resource "google_compute_subnetwork" "workload" {
  name                     = "${var.name}-workload"
  region                   = var.region
  network                  = google_compute_network.workload.id
  ip_cidr_range            = var.subnet_cidr
  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# --- Identidad del workload --------------------------------------------------------

resource "google_service_account" "app" {
  account_id   = "${var.name}-app"
  display_name = "Workload de ${var.name}"
}

# --- Clave (CMEK) -------------------------------------------------------------------

# Con replicación automática la clave tiene que estar en la multi-región global de Cloud KMS
# (gotcha: cmek-key-location-and-lifecycle).
resource "google_kms_key_ring" "secrets" {
  name     = "${var.name}-secrets"
  location = "global"
}

resource "google_kms_crypto_key" "secrets" {
  name            = "app-secrets"
  key_ring        = google_kms_key_ring.secrets.id
  purpose         = "ENCRYPT_DECRYPT"
  rotation_period = var.kms_rotation_period

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_kms_crypto_key_iam_member" "secret_manager_agent" {
  crypto_key_id = google_kms_crypto_key.secrets.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = local.secret_manager_agent
}

# --- Secreto -------------------------------------------------------------------------

resource "google_secret_manager_secret" "this" {
  secret_id           = "${var.name}-app-secret"
  labels              = var.labels
  deletion_protection = var.deletion_protection

  # La política de replicación no se puede cambiar después de crear el secreto
  # (gotcha: user-managed-replication-fails-with-region-outage).
  replication {
    auto {
      customer_managed_encryption {
        kms_key_name = google_kms_crypto_key.secrets.id
      }
    }
  }

  dynamic "topics" {
    for_each = var.rotation == null ? [] : [var.rotation.topic]
    content {
      name = topics.value
    }
  }

  # Secret Manager solo publica SECRET_ROTATE; la rotación real la hace un suscriptor
  # (gotcha: rotation-is-a-pubsub-message).
  dynamic "rotation" {
    for_each = var.rotation == null ? [] : [var.rotation]
    content {
      next_rotation_time = rotation.value.next_rotation_time
      rotation_period    = rotation.value.rotation_period
    }
  }

  depends_on = [google_kms_crypto_key_iam_member.secret_manager_agent]
}

# Binding a nivel de secreto, no de proyecto.
resource "google_secret_manager_secret_iam_member" "app" {
  secret_id = google_secret_manager_secret.this.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.app.email}"
}

# Para publicar la notificación de rotación, el service agent necesita pubsub.publisher en el topic.
resource "google_pubsub_topic_iam_member" "rotation_publisher" {
  count = var.rotation == null ? 0 : 1

  topic  = var.rotation.topic
  role   = "roles/pubsub.publisher"
  member = local.secret_manager_agent
}

# --- Auditoría -----------------------------------------------------------------------

# AccessSecretVersion es DATA_READ y los Data Access logs vienen apagados (gotcha: data-access-logs-off-by-default).
resource "google_project_iam_audit_config" "secret_manager" {
  count = var.enable_data_access_audit ? 1 : 0

  project = var.project_id
  service = "secretmanager.googleapis.com"

  audit_log_config {
    log_type = "DATA_READ"
  }

  audit_log_config {
    log_type = "ADMIN_READ"
  }
}
