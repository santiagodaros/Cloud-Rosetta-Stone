variable "name" {
  description = "Prefijo para nombrar los recursos (ej. \"ingest-demo\")."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.name))
    error_message = "name: 3-20 caracteres, minúsculas, números o guiones."
  }
}

variable "bucket_name" {
  description = "Nombre global único del bucket S3."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "bucket_name: 3-63 caracteres, minúsculas, números, puntos o guiones."
  }
}

variable "region" {
  description = "Región de AWS."
  type        = string
  default     = "us-east-1"
}

variable "ttl_days" {
  description = "Días desde la creación tras los cuales expira el objeto."
  type        = number
  default     = 7

  validation {
    condition     = var.ttl_days >= 1 && floor(var.ttl_days) == var.ttl_days
    error_message = "ttl_days debe ser un entero >= 1."
  }
}

variable "object_prefix" {
  description = "Prefijo de las keys a las que aplica el TTL (en S3 el prefijo NO incluye el bucket)."
  type        = string
  default     = "incoming/"
}

variable "vpc_cidr" {
  description = "CIDR de la VPC del workload."
  type        = string
  default     = "10.20.0.0/16"
}

variable "break_glass_principal_arns" {
  description = "ARNs (admite comodines) excluidos del Deny por VPC endpoint: consola, CI. Gotcha: sourcevpce-lockout."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags aplicados a todos los recursos."
  type        = map(string)
  default     = {}
}
