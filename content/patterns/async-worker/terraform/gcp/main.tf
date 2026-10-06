# Worker asíncrono con escala a cero — GCP
#
# Pub/Sub push autenticado (OIDC) hacia Cloud Run con ingress interno,
# dead-letter topic con su suscripción y permisos del service agent, y
# resultados en Cloud Storage.

data "google_project" "this" {
  project_id = var.project_id
}

locals {
  pubsub_service_agent = "serviceAccount:service-${data.google_project.this.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

# --- Identidades -----------------------------------------------------------------

resource "google_service_account" "worker" {
  account_id   = "${var.name}-worker"
  display_name = "Worker (${var.name})"
}

# Identidad con la que Pub/Sub firma el OIDC token del push.
resource "google_service_account" "push" {
  account_id   = "${var.name}-push"
  display_name = "Pub/Sub push invoker (${var.name})"
}

# --- Resultados ------------------------------------------------------------------

resource "google_storage_bucket" "results" {
  #checkov:skip=CKV_GCP_62:Access logs fuera de alcance; usar Cloud Audit Logs (Data Access) si se requiere.
  #checkov:skip=CKV_GCP_78:Resultados regenerables con TTL; versioning duplicaría costo.
  name                        = var.results_bucket_name
  location                    = upper(var.region)
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  labels                      = var.labels

  soft_delete_policy {
    retention_duration_seconds = 604800
  }

  lifecycle_rule {
    condition {
      age = var.results_ttl_days
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
}

resource "google_storage_bucket_iam_member" "worker_results" {
  bucket = google_storage_bucket.results.name
  role   = "roles/storage.objectCreator"
  member = google_service_account.worker.member
}

# --- Worker en Cloud Run -----------------------------------------------------------

resource "google_cloud_run_v2_service" "worker" {
  name     = "${var.name}-worker"
  location = var.region
  # Pub/Sub cuenta como origen interno: no hace falta exponer el servicio.
  ingress             = "INGRESS_TRAFFIC_INTERNAL_ONLY"
  deletion_protection = false
  labels              = var.labels

  template {
    service_account = google_service_account.worker.email
    timeout         = "${var.ack_deadline_seconds}s"

    scaling {
      min_instance_count = 0
      max_instance_count = var.max_instances
    }

    containers {
      image = var.container_image

      env {
        name  = "RESULTS_BUCKET"
        value = google_storage_bucket.results.name
      }
    }
  }
}

resource "google_cloud_run_v2_service_iam_member" "push_invoker" {
  name     = google_cloud_run_v2_service.worker.name
  location = google_cloud_run_v2_service.worker.location
  role     = "roles/run.invoker"
  member   = google_service_account.push.member
}

# --- Pub/Sub -----------------------------------------------------------------------

resource "google_pubsub_topic" "jobs" {
  #checkov:skip=CKV_GCP_83:Cifrado con claves administradas por Google; CMEK opcional.
  name   = "${var.name}-jobs"
  labels = var.labels
}

resource "google_pubsub_topic" "dead_letter" {
  #checkov:skip=CKV_GCP_83:Cifrado con claves administradas por Google; CMEK opcional.
  name   = "${var.name}-jobs-dead-letter"
  labels = var.labels
}

# Sin suscripción, lo que llega al dead-letter topic se pierde
# (gotcha: dead-letter-topic-needs-subscription).
resource "google_pubsub_subscription" "dead_letter" {
  name                       = "${var.name}-jobs-dead-letter"
  topic                      = google_pubsub_topic.dead_letter.id
  message_retention_duration = "604800s"
  ack_deadline_seconds       = 60
  labels                     = var.labels

  expiration_policy {
    ttl = ""
  }
}

resource "google_pubsub_subscription" "jobs" {
  name                 = "${var.name}-jobs-push"
  topic                = google_pubsub_topic.jobs.id
  ack_deadline_seconds = var.ack_deadline_seconds
  labels               = var.labels

  push_config {
    push_endpoint = google_cloud_run_v2_service.worker.uri

    oidc_token {
      service_account_email = google_service_account.push.email
    }
  }

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dead_letter.id
    max_delivery_attempts = var.max_delivery_attempts
  }

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  expiration_policy {
    ttl = ""
  }

  depends_on = [google_pubsub_subscription.dead_letter]
}

# El service agent de Pub/Sub es quien mueve mensajes al dead-letter
# (gotcha: dlq-needs-service-agent-roles).
resource "google_pubsub_topic_iam_member" "dead_letter_publisher" {
  topic  = google_pubsub_topic.dead_letter.id
  role   = "roles/pubsub.publisher"
  member = local.pubsub_service_agent
}

resource "google_pubsub_subscription_iam_member" "source_subscriber" {
  subscription = google_pubsub_subscription.jobs.id
  role         = "roles/pubsub.subscriber"
  member       = local.pubsub_service_agent
}
