variable "name" {
  description = "Prefijo para nombrar los recursos (ej. \"api-demo\")."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.name))
    error_message = "name: 3-20 caracteres, minúsculas, números o guiones."
  }
}

variable "region" {
  description = "Región de AWS."
  type        = string
  default     = "us-east-1"
}

variable "availability_zones" {
  description = "Dos AZs para las subnets privadas (RDS exige un subnet group en al menos dos)."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]

  validation {
    condition     = length(var.availability_zones) == 2
    error_message = "Indicá exactamente dos AZs."
  }
}

variable "vpc_cidr" {
  description = "CIDR de la VPC."
  type        = string
  default     = "10.50.0.0/16"
}

variable "client_cidrs" {
  description = "CIDRs que pueden llamar a la API (red corporativa, VPCs peereadas)."
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "certificate_arn" {
  description = "ARN del certificado de ACM para el listener HTTPS (gotcha: internal-alb-certificate)."
  type        = string
}

variable "container_image" {
  description = "Imagen de la API (en ECR, alcanzable por los VPC endpoints)."
  type        = string
}

variable "container_port" {
  description = "Puerto en el que escucha la API."
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "Path del health check del target group."
  type        = string
  default     = "/healthz"
}

variable "desired_count" {
  description = "Tareas de ECS. Mínimo 1: el servicio no escala a cero."
  type        = number
  default     = 1
}

variable "db_instance_class" {
  description = "Clase de instancia de RDS."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_multi_az" {
  description = "Multi-AZ para RDS (duplica el costo de cómputo)."
  type        = bool
  default     = false
}

variable "database_name" {
  description = "Base de datos de la aplicación."
  type        = string
  default     = "app"
}

variable "db_app_user" {
  description = "Usuario de base que usa la app con IAM auth (se crea con SQL, ver output app_user_sql)."
  type        = string
  default     = "app_iam"
}

variable "tags" {
  description = "Tags aplicados a todos los recursos."
  type        = map(string)
  default     = {}
}
