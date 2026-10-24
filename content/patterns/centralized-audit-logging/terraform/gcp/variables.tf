variable "project_id" {
  description = "Proyecto central de logging: aloja el bucket de logs. Tiene que ser distinto de los proyectos de origen."
  type        = string
}

variable "region" {
  description = "Región por defecto del provider."
  type        = string
  default     = "us-central1"
}

variable "name" {
  description = "Prefijo para nombrar el sink y el bucket (ej. \"audit\")."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,19}$", var.name))
    error_message = "name: 3-20 caracteres, empieza con letra, minúsculas, números o guiones."
  }
}

variable "organization_id" {
  description = "ID numérico de la organización de origen. Exactamente uno entre organization_id y folder_id."
  type        = string
  default     = null
}

variable "folder_id" {
  description = "ID numérico de la carpeta de origen. Exactamente uno entre organization_id y folder_id."
  type        = string
  default     = null
}

variable "bucket_location" {
  description = "Ubicación del bucket de logs. No se puede cambiar después de crearlo."
  type        = string
  default     = "global"
}

variable "retention_days" {
  description = "Retención del bucket. No se puede extender la de un bucket que está en una carpeta u organización: por eso el bucket vive en un proyecto (gotcha: bucket-retention-and-lock)."
  type        = number
  default     = 365

  validation {
    condition     = var.retention_days >= 1 && floor(var.retention_days) == var.retention_days
    error_message = "retention_days: un entero de 1 o más."
  }
}

variable "lock_bucket" {
  description = "Bloquea el bucket. Es irreversible: tampoco se podrá borrar hasta que cada entrada cumpla la retención (gotcha: bucket-retention-and-lock)."
  type        = bool
  default     = false
}

variable "log_filter" {
  description = "Filtro de inclusión del sink. Por defecto, todos los audit logs."
  type        = string
  default     = "logName:\"cloudaudit.googleapis.com\""
}

variable "data_access_log_services" {
  description = "Servicios (o allServices) con Data Access audit logs habilitados en el origen. Vacío = no se toca la configuración: salvo BigQuery, vienen deshabilitados (gotcha: data-access-logs-enabled-at-the-source)."
  type        = list(string)
  default     = []
}
