output "bucket_id" {
  description = "Bucket de logs central."
  value       = google_logging_project_bucket_config.audit.id
}

output "sink_writer_identity" {
  description = "Identidad con la que el sink escribe en el destino; necesita acceso al destino (gotcha: writer-identity-needs-destination-access)."
  value       = local.writer_identity
}
