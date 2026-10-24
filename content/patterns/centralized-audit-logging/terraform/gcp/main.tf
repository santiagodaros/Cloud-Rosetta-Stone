# Logs de auditoría centralizados — GCP
#
# Un sink agregado en la organización (o carpeta) enruta los audit logs de todos los proyectos
# hijos a un log bucket de un proyecto central. La identidad del sink recibe permiso de
# escritura sobre ese proyecto: sin eso, el sink no exporta nada.

locals {
  use_org = var.organization_id != null

  sink_destination = "logging.googleapis.com/projects/${var.project_id}/locations/${var.bucket_location}/buckets/${google_logging_project_bucket_config.audit.bucket_id}"

  writer_identity = local.use_org ? google_logging_organization_sink.audit[0].writer_identity : google_logging_folder_sink.audit[0].writer_identity
}

# Bucket en un proyecto: la retención de uno en carpeta u organización no se puede extender
# (gotcha: bucket-retention-and-lock).
resource "google_logging_project_bucket_config" "audit" {
  project        = var.project_id
  location       = var.bucket_location
  bucket_id      = "${var.name}-audit"
  retention_days = var.retention_days
  locked         = var.lock_bucket
  description    = "Audit logs centralizados de la organización o carpeta de origen."

  lifecycle {
    precondition {
      condition     = (var.organization_id == null) != (var.folder_id == null)
      error_message = "Definí exactamente uno entre organization_id y folder_id."
    }
  }
}

# include_children = true: sin eso el sink solo ve los logs del propio recurso padre y no los de
# los proyectos (gotcha: include-children-defaults-to-false). No intercepta: los proyectos
# conservan sus propias copias (gotcha: intercepting-sink-hides-logs-from-child-sinks).
resource "google_logging_organization_sink" "audit" {
  count = local.use_org ? 1 : 0

  name             = "${var.name}-audit"
  org_id           = var.organization_id
  destination      = local.sink_destination
  filter           = var.log_filter
  include_children = true
  # Explícito: un sink que intercepta saca los logs de los sinks de los proyectos hijos.
  intercept_children = false
  description        = "Audit logs de todos los proyectos de la organización hacia el proyecto central."
}

resource "google_logging_folder_sink" "audit" {
  count = local.use_org ? 0 : 1

  name               = "${var.name}-audit"
  folder             = var.folder_id
  destination        = local.sink_destination
  filter             = var.log_filter
  include_children   = true
  intercept_children = false
  description        = "Audit logs de todos los proyectos de la carpeta hacia el proyecto central."
}

# La identidad del sink necesita logging.logEntries.route (Logs Writer) y el rol del destino
# (Logs Bucket Writer) (gotcha: writer-identity-needs-destination-access).
resource "google_project_iam_member" "sink_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = local.writer_identity
}

resource "google_project_iam_member" "sink_bucket_writer" {
  project = var.project_id
  role    = "roles/logging.bucketWriter"
  member  = local.writer_identity
}

# Data Access audit logs: se habilitan en el origen, a nivel de organización o carpeta, para que
# apliquen a los proyectos actuales y nuevos (gotcha: data-access-logs-enabled-at-the-source).
resource "google_organization_iam_audit_config" "data_access" {
  for_each = local.use_org ? toset(var.data_access_log_services) : toset([])

  org_id  = var.organization_id
  service = each.value

  audit_log_config {
    log_type = "ADMIN_READ"
  }

  audit_log_config {
    log_type = "DATA_READ"
  }

  audit_log_config {
    log_type = "DATA_WRITE"
  }
}

resource "google_folder_iam_audit_config" "data_access" {
  for_each = local.use_org ? toset([]) : toset(var.data_access_log_services)

  folder  = var.folder_id
  service = each.value

  audit_log_config {
    log_type = "ADMIN_READ"
  }

  audit_log_config {
    log_type = "DATA_READ"
  }

  audit_log_config {
    log_type = "DATA_WRITE"
  }
}
