output "alb_dns_name" {
  description = "DNS interno del ALB (apuntá un registro de tu zona privada a este nombre)."
  value       = aws_lb.this.dns_name
}

output "db_address" {
  description = "Endpoint de RDS."
  value       = aws_db_instance.this.address
}

output "master_user_secret_arn" {
  description = "Secreto de Secrets Manager con la contraseña del master (solo para administración)."
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}

output "app_user_sql" {
  description = "SQL que hay que ejecutar como master para crear el usuario IAM de la app (gotcha: rds-iam-user-needs-sql)."
  value       = <<-SQL
    CREATE USER ${var.db_app_user};
    GRANT rds_iam TO ${var.db_app_user};
    GRANT CONNECT ON DATABASE ${var.database_name} TO ${var.db_app_user};
    -- Conectado a la base '${var.database_name}':
    GRANT USAGE ON SCHEMA public TO ${var.db_app_user};
    GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO ${var.db_app_user};
  SQL
}
