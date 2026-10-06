variable "name" {
  description = "Nombre del rol de despliegue (ej. \"deploy-web\")."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9+=,.@_-]{3,64}$", var.name))
    error_message = "name: 3-64 caracteres válidos para un rol IAM."
  }
}

variable "region" {
  description = "Región del provider (IAM es global)."
  type        = string
  default     = "us-east-1"
}

variable "create_oidc_provider" {
  description = "Crear el OIDC provider de GitHub. Hay uno solo por URL y por cuenta: si ya existe, false y se referencia (gotcha: one-oidc-provider-per-account)."
  type        = bool
  default     = true
}

variable "github" {
  description = <<-EOT
    Repositorio que puede desplegar. owner_id y repository_id (numéricos) activan el formato inmutable del
    claim sub ("repo:owner@123/repo@456:..."), que GitHub usa por defecto en repos creados, renombrados o
    transferidos desde el 15/07/2026.
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
  description = "Environments de GitHub que pueden asumir el rol (match exacto con StringEquals)."
  type        = set(string)
  default     = ["production"]

  validation {
    condition     = length(var.environments) >= 1 && alltrue([for e in var.environments : !can(regex("[*?]", e))])
    error_message = "environments: al menos uno y sin comodines (el módulo usa StringEquals a propósito)."
  }
}

variable "policy_arns" {
  description = "Policies administradas que necesita el despliegue (mínimo privilegio)."
  type        = set(string)

  validation {
    condition     = !contains(var.policy_arns, "arn:aws:iam::aws:policy/AdministratorAccess")
    error_message = "policy_arns: AdministratorAccess no. Acotá los permisos a lo que despliega el pipeline."
  }
}

variable "max_session_duration" {
  description = "Duración máxima de la sesión en segundos (1 h a 12 h). Si el apply dura más que la sesión, falla a mitad de camino."
  type        = number
  default     = 3600

  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 43200
    error_message = "max_session_duration: entre 3600 y 43200."
  }
}

variable "tags" {
  description = "Tags comunes."
  type        = map(string)
  default     = {}
}
