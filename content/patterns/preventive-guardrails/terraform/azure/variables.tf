variable "name" {
  description = "Prefijo para nombrar la definición y la asignación (ej. \"org\"). Máximo 12 caracteres: el nombre de una asignación no puede pasar de 24."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,12}$", var.name))
    error_message = "name: 3-12 caracteres, minúsculas, números o guiones."
  }
}

variable "management_group_id" {
  description = "ID completo del management group donde se define y se asigna la política (\"/providers/Microsoft.Management/managementGroups/<nombre>\")."
  type        = string

  validation {
    condition     = can(regex("^/providers/Microsoft.Management/managementGroups/[^/]+$", var.management_group_id))
    error_message = "management_group_id: usá el ID completo del management group, no solo su nombre."
  }
}

variable "effect" {
  description = "Efecto de la política. \"deny\" bloquea crear o modificar cuentas con acceso anónimo; \"audit\" solo las marca no conformes y la request pasa (gotcha: audit-does-not-block)."
  type        = string
  default     = "deny"

  validation {
    condition     = contains(["deny", "audit"], var.effect)
    error_message = "effect: \"deny\" o \"audit\"."
  }
}

variable "enforce" {
  description = "false asigna la política en modo DoNotEnforce: evalúa cumplimiento sin aplicar el efecto. Es el paso previo a pasar a deny (gotcha: donotenforce-evaluates-without-blocking)."
  type        = bool
  default     = true
}

variable "not_scopes" {
  description = "Scopes (suscripciones, resource groups) que quedan fuera de la evaluación. Es una exclusión, no una excepción con trazabilidad: preferí exemptions."
  type        = list(string)
  default     = []
}

variable "exemptions" {
  description = "Excepciones por suscripción. Cada una exige vencimiento (expires_on, RFC 3339 en UTC), motivo, quién la pidió y quién la aprobó (gotcha: exemption-expiry-is-optional)."
  type = map(object({
    subscription_id = string
    category        = optional(string, "Waiver")
    expires_on      = string
    reason          = string
    requested_by    = string
    approved_by     = string
    ticket          = string
  }))
  default = {}

  validation {
    condition     = alltrue([for e in values(var.exemptions) : can(regex("^/subscriptions/[0-9a-fA-F-]{36}$", e.subscription_id))])
    error_message = "exemptions: subscription_id con el formato \"/subscriptions/<guid>\"."
  }

  validation {
    condition     = alltrue([for e in values(var.exemptions) : contains(["Waiver", "Mitigated"], e.category)])
    error_message = "exemptions: category es \"Waiver\" o \"Mitigated\"."
  }

  validation {
    condition     = alltrue([for e in values(var.exemptions) : can(formatdate("YYYY", e.expires_on))])
    error_message = "exemptions: expires_on tiene que ser una fecha RFC 3339, por ejemplo 2027-03-31T23:59:00Z."
  }

  validation {
    condition = alltrue([
      for e in values(var.exemptions) :
      length(trimspace(e.reason)) > 0 && length(trimspace(e.requested_by)) > 0 && length(trimspace(e.approved_by)) > 0 && length(trimspace(e.ticket)) > 0
    ])
    error_message = "exemptions: reason, requested_by, approved_by y ticket no pueden estar vacíos."
  }
}
