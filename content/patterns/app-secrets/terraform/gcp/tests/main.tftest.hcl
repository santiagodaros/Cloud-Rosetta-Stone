# Tests sin credenciales ni recursos reales: mock_provider + command = plan.

mock_provider "google" {}

override_data {
  target = data.google_project.this
  values = {
    number = "123456789012"
  }
}

variables {
  project_id = "demo-project"
  name       = "secrets-test"
}

run "private_google_access_on_the_subnet" {
  command = plan

  assert {
    condition     = google_compute_subnetwork.workload.private_ip_google_access
    error_message = "La subnet del workload tiene que tener Private Google Access."
  }
}

run "secret_is_cmek_with_automatic_replication" {
  command = plan

  assert {
    condition     = length(google_secret_manager_secret.this.replication[0].auto) == 1 && length(google_secret_manager_secret.this.replication[0].auto[0].customer_managed_encryption) == 1
    error_message = "El secreto usa replicación automática con CMEK."
  }

  assert {
    condition     = google_kms_key_ring.secrets.location == "global"
    error_message = "Con replicación automática, la clave tiene que estar en global."
  }

  assert {
    condition     = google_secret_manager_secret.this.deletion_protection
    error_message = "El secreto viene con deletion_protection."
  }
}

run "app_reads_one_secret_only" {
  command = plan

  assert {
    condition     = google_secret_manager_secret_iam_member.app.role == "roles/secretmanager.secretAccessor"
    error_message = "La service account solo lee el secreto (secretAccessor a nivel de secreto)."
  }
}

run "data_access_logs_enabled" {
  command = plan

  assert {
    condition     = contains([for c in google_project_iam_audit_config.secret_manager[0].audit_log_config : c.log_type], "DATA_READ")
    error_message = "Hay que activar DATA_READ para ver AccessSecretVersion."
  }
}

run "rotation_is_opt_in" {
  command = plan

  assert {
    condition     = length(google_secret_manager_secret.this.rotation) == 0 && length(google_pubsub_topic_iam_member.rotation_publisher) == 0
    error_message = "Sin var.rotation no hay rotación ni permisos de Pub/Sub."
  }
}

run "rotation_when_requested" {
  command = plan

  variables {
    rotation = {
      topic              = "projects/demo-project/topics/secret-rotation"
      next_rotation_time = "2027-01-01T09:00:00Z"
      rotation_period    = "2592000s"
    }
  }

  assert {
    condition     = google_secret_manager_secret.this.rotation[0].rotation_period == "2592000s" && length(google_secret_manager_secret.this.topics) == 1
    error_message = "Con var.rotation el secreto tiene que llevar el topic y el período."
  }
}

run "audit_can_be_disabled" {
  command = plan

  variables {
    enable_data_access_audit = false
  }

  assert {
    condition     = length(google_project_iam_audit_config.secret_manager) == 0
    error_message = "enable_data_access_audit = false no tiene que crear el audit config."
  }
}
