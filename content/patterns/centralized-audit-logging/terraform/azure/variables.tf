variable "name" {
  description = "Prefijo para nombrar los recursos (ej. \"audit\")."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.name))
    error_message = "name: 3-20 caracteres, minúsculas, números o guiones."
  }
}

variable "location" {
  description = "Región del workspace de Log Analytics."
  type        = string
  default     = "eastus2"
}

variable "source_subscription_ids" {
  description = "Suscripciones cuyo Activity Log se exporta al workspace: un diagnostic setting por suscripción (gotcha: management-group-setting-misses-subscription-events). Quien aplica necesita RBAC sobre cada una y sobre la suscripción central (gotcha: destination-in-another-subscription-needs-rbac)."
  type        = list(string)

  validation {
    condition     = length(var.source_subscription_ids) > 0 && alltrue([for s in var.source_subscription_ids : can(regex("^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$", s))])
    error_message = "source_subscription_ids: al menos una suscripción, cada una con formato de GUID."
  }
}

variable "retention_in_days" {
  description = "Retención del workspace. El Activity Log se conserva 90 días si no se exporta (gotcha: activity-log-default-retention)."
  type        = number
  default     = 365

  validation {
    condition     = var.retention_in_days >= 1 && floor(var.retention_in_days) == var.retention_in_days
    error_message = "retention_in_days: un entero de 1 o más."
  }
}

variable "archive_storage_account_id" {
  description = "Storage account existente (Standard, con inmutabilidad configurada) donde archivar además una copia. Null = solo el workspace (gotcha: storage-destination-requirements)."
  type        = string
  default     = null
}

variable "reader_principal_ids" {
  description = "Object IDs que leen el workspace con el rol Log Analytics Reader."
  type        = list(string)
  default     = []
}

variable "lock_workspace" {
  description = "Bloqueo CanNotDelete sobre el workspace de auditoría."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags de todos los recursos."
  type        = map(string)
  default     = {}
}
