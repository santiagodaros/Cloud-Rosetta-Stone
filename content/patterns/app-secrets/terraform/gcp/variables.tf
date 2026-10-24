variable "project_id" {
  description = "Proyecto donde viven el secreto, la clave y la red."
  type        = string
}

variable "region" {
  description = "Región de la subnet donde corre el workload."
  type        = string
  default     = "us-central1"
}

variable "name" {
  description = "Prefijo para nombrar los recursos (ej. \"app-secrets\")."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,19}$", var.name))
    error_message = "name: 3-20 caracteres, empieza con letra, minúsculas, números o guiones."
  }
}

variable "subnet_cidr" {
  description = "Rango de la subnet del workload, con Private Google Access."
  type        = string
  default     = "10.30.0.0/24"
}

variable "kms_rotation_period" {
  description = "Rotación automática de la clave de Cloud KMS. Las versiones ya escritas del secreto no se recifran (gotcha: cmek-key-location-and-lifecycle)."
  type        = string
  default     = "7776000s"
}

variable "rotation" {
  description = "Rotación del secreto: Secret Manager publica SECRET_ROTATE en el topic y alguien tiene que suscribirse y crear la versión nueva (gotcha: rotation-is-a-pubsub-message). null = sin rotación. rotation_period: mínimo 3600s."
  type = object({
    topic              = string
    next_rotation_time = string
    rotation_period    = string
  })
  default = null
}

variable "enable_data_access_audit" {
  description = "Activa los Data Access audit logs de Secret Manager en el proyecto (gotcha: data-access-logs-off-by-default). Es authoritative para el servicio: si ya lo configurás en otro lado, apagalo."
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Impide que terraform destroy borre el secreto."
  type        = bool
  default     = true
}

variable "labels" {
  description = "Labels comunes."
  type        = map(string)
  default     = {}
}
