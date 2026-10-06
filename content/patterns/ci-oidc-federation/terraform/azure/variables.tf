variable "name" {
  description = "Prefijo para nombrar los recursos (ej. \"deploy-web\")."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,24}$", var.name))
    error_message = "name: 3-24 caracteres, minúsculas, números o guiones."
  }
}

variable "location" {
  description = "Región de Azure de la identidad (no tiene que ser la de los recursos que despliega)."
  type        = string
  default     = "eastus2"
}

variable "github" {
  description = <<-EOT
    Repositorio que puede desplegar. owner_id y repository_id (numéricos) activan el formato inmutable del
    claim sub ("repo:owner@123/repo@456:..."), que GitHub usa por defecto en repos creados, renombrados o
    transferidos desde el 15/07/2026 (gotcha: github-sub-format-changed).
  EOT
  type = object({
    owner         = string
    repository    = string
    owner_id      = optional(number)
    repository_id = optional(number)
  })

  validation {
    condition     = (var.github.owner_id == null) == (var.github.repository_id == null)
    error_message = "github: owner_id y repository_id van juntos (formato inmutable) o ninguno de los dos."
  }
}

variable "environments" {
  description = "Environments de GitHub que pueden desplegar. Uno por federated identity credential (sin comodines)."
  type        = set(string)
  default     = ["production"]

  validation {
    # Máximo 20 credenciales por identidad (gotcha: fic-exact-match-max-20).
    condition     = length(var.environments) >= 1 && length(var.environments) <= 20
    error_message = "environments: entre 1 y 20 (límite de federated identity credentials por identidad)."
  }

  validation {
    condition     = alltrue([for e in var.environments : !strcontains(e, "*")])
    error_message = "environments: los federated identity credentials no admiten comodines."
  }
}

variable "target_scope_id" {
  description = "ID del scope donde despliega el pipeline (idealmente un resource group, no la suscripción)."
  type        = string

  validation {
    condition     = can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+$", var.target_scope_id))
    error_message = "target_scope_id: tiene que ser un resource group (/subscriptions/<id>/resourceGroups/<nombre>)."
  }
}

variable "role_definition_name" {
  description = "Rol sobre el scope. Contributor no puede crear role assignments (gotcha: contributor-cannot-assign-roles)."
  type        = string
  default     = "Contributor"

  validation {
    condition     = !contains(["Owner", "User Access Administrator"], var.role_definition_name)
    error_message = "role_definition_name: Owner y User Access Administrator no; si el pipeline asigna roles, usá un role assignment con condición aparte."
  }
}

variable "tags" {
  description = "Tags comunes."
  type        = map(string)
  default     = {}
}
