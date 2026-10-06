output "service_uri" {
  description = "URL run.app del servicio (solo alcanzable con ingress interno + ID token)."
  value       = google_cloud_run_v2_service.api.uri
}

output "instance_connection_name" {
  description = "Connection name de Cloud SQL para el connector."
  value       = google_sql_database_instance.this.connection_name
}

output "db_iam_user" {
  description = "Usuario de base de la Service Account (sin .gserviceaccount.com)."
  value       = google_sql_user.api.name
}

output "app_grants_sql" {
  description = "Permisos sobre tablas: siguen siendo SQL (gotcha: iam-user-created-by-api)."
  value       = <<-SQL
    -- Conectado a la base '${var.database_name}' como un usuario con privilegios:
    GRANT USAGE ON SCHEMA public TO "${google_sql_user.api.name}";
    GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO "${google_sql_user.api.name}";
  SQL
}
