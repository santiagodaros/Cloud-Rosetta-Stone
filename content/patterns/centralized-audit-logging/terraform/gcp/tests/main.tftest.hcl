# Tests sin credenciales ni recursos reales: mock_provider + command = plan.

mock_provider "google" {}

variables {
  project_id      = "central-logging"
  name            = "audit-test"
  organization_id = "123456789012"
}

run "sink_includes_children" {
  command = plan

  assert {
    condition     = google_logging_organization_sink.audit[0].include_children
    error_message = "Sin include_children el sink agregado solo ve los logs del propio recurso padre."
  }

  assert {
    condition     = !google_logging_organization_sink.audit[0].intercept_children
    error_message = "El sink no intercepta: los proyectos conservan sus propias copias de los logs."
  }
}

run "sink_writes_to_the_central_bucket" {
  command = plan

  assert {
    condition     = google_logging_organization_sink.audit[0].destination == "logging.googleapis.com/projects/central-logging/locations/global/buckets/audit-test-audit"
    error_message = "El destino es el log bucket del proyecto central."
  }

  assert {
    condition     = google_logging_project_bucket_config.audit.project == "central-logging"
    error_message = "El bucket vive en el proyecto central, no en la organización."
  }
}

run "writer_identity_gets_log_writer_and_bucket_writer" {
  command = plan

  assert {
    condition     = google_project_iam_member.sink_log_writer.role == "roles/logging.logWriter" && google_project_iam_member.sink_bucket_writer.role == "roles/logging.bucketWriter"
    error_message = "La identidad del sink necesita Logs Writer y Logs Bucket Writer sobre el proyecto de destino."
  }

  assert {
    condition     = google_project_iam_member.sink_log_writer.project == "central-logging" && google_project_iam_member.sink_bucket_writer.project == "central-logging"
    error_message = "Los permisos se otorgan en el proyecto que contiene el destino."
  }
}

run "bucket_retention_and_lock" {
  command = plan

  variables {
    retention_days = 730
  }

  assert {
    condition     = google_logging_project_bucket_config.audit.retention_days == 730
    error_message = "La retención del bucket es la que define el patrón."
  }

  assert {
    condition     = !google_logging_project_bucket_config.audit.locked
    error_message = "Bloquear el bucket es irreversible: tiene que ser una decisión explícita."
  }
}

run "folder_scope_uses_a_folder_sink" {
  command = plan

  variables {
    organization_id = null
    folder_id       = "987654321098"
  }

  assert {
    condition     = length(google_logging_organization_sink.audit) == 0 && google_logging_folder_sink.audit[0].include_children
    error_message = "Con folder_id el sink agregado es de carpeta y también incluye a los hijos."
  }
}

run "data_access_logs_are_untouched_by_default" {
  command = plan

  assert {
    condition     = length(google_organization_iam_audit_config.data_access) == 0
    error_message = "Habilitar Data Access logs es una decisión de volumen y costo: no se toca por defecto."
  }
}

run "data_access_logs_enabled_for_listed_services" {
  command = plan

  variables {
    data_access_log_services = ["storage.googleapis.com"]
  }

  assert {
    condition     = length(google_organization_iam_audit_config.data_access) == 1
    error_message = "Los servicios listados reciben configuración de Data Access en la organización."
  }
}

run "rejects_both_organization_and_folder" {
  command = plan

  variables {
    folder_id = "987654321098"
  }

  expect_failures = [google_logging_project_bucket_config.audit]
}
