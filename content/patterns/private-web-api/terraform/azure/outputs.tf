output "api_fqdn" {
  description = "FQDN interno de la API (resuelve vía la zona DNS privada del environment)."
  value       = azurerm_container_app.api.ingress[0].fqdn
}

output "postgres_fqdn" {
  description = "FQDN del servidor PostgreSQL (resuelve a la IP del Private Endpoint desde la VNet)."
  value       = azurerm_postgresql_flexible_server.this.fqdn
}

output "app_role_sql" {
  description = "SQL que un admin Entra tiene que ejecutar para crear el rol de la app con permisos mínimos (gotcha: pg-entra-app-role-needs-sql)."
  value       = <<-SQL
    -- Conectado a la base 'postgres' como administrador Entra:
    SELECT * FROM pgaadauth_create_principal('${azurerm_user_assigned_identity.api.name}', false, false);
    -- Conectado a la base '${var.database_name}':
    GRANT CONNECT ON DATABASE "${var.database_name}" TO "${azurerm_user_assigned_identity.api.name}";
    GRANT USAGE ON SCHEMA public TO "${azurerm_user_assigned_identity.api.name}";
    GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO "${azurerm_user_assigned_identity.api.name}";
  SQL
}
