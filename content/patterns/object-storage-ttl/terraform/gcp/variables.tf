variable "project_id" {
  description = "ID del proyecto de GCP."
  type        = string
}

variable "name" {
  description = "Prefijo para nombrar los recursos (ej. \"ingest-demo\")."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,19}$", var.name))
    error_message = "name: 3-20 caracteres, empieza con letra, minúsculas, números o guiones."
  }
}

variable "bucket_name" {
  description = "Nombre global único del bucket."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9_.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "bucket_name: 3-63 caracteres, minúsculas, números, puntos, guiones o guiones bajos."
  }
}

variable "region" {
  description = "Región de GCP (el bucket se crea regional en la misma región)."
  type        = string
  default     = "us-central1"
}

variable "ttl_days" {
  description = "Edad en días tras la cual se borra el objeto."
  type        = number
  default     = 7

  validation {
    condition     = var.ttl_days >= 1 && floor(var.ttl_days) == var.ttl_days
    error_message = "ttl_days debe ser un entero >= 1."
  }
}

variable "object_prefix" {
  description = "Prefijo de los objetos a los que aplica el TTL (en GCS el prefijo NO incluye el bucket)."
  type        = string
  default     = "incoming/"
}

variable "soft_delete_retention_seconds" {
  description = "Retención de soft delete. 0 lo deshabilita; el default de GCS es 7 días (gotcha: soft-delete-default-7-days)."
  type        = number
  default     = 0

  validation {
    condition     = var.soft_delete_retention_seconds == 0 || (var.soft_delete_retention_seconds >= 604800 && var.soft_delete_retention_seconds <= 7776000)
    error_message = "soft_delete_retention_seconds: 0 (deshabilitado) o entre 7 y 90 días (604800-7776000)."
  }
}

variable "subnet_cidr" {
  description = "CIDR de la subnet del workload."
  type        = string
  default     = "10.30.0.0/24"
}

variable "restrict_to_vpc" {
  description = "Activa bucket IP filtering para aceptar requests solo desde la VPC. Puede dejar afuera al pipeline si corre fuera de la VPC."
  type        = bool
  default     = false
}

variable "labels" {
  description = "Labels aplicados a los recursos que los soportan."
  type        = map(string)
  default     = {}
}
