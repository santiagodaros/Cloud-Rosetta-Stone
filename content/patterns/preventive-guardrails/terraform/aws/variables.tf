variable "name" {
  description = "Prefijo para nombrar la política (ej. \"org\")."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.name))
    error_message = "name: 3-20 caracteres, minúsculas, números o guiones."
  }
}

variable "region" {
  description = "Región desde la que el provider llama a la API de Organizations."
  type        = string
  default     = "us-east-1"
}

variable "target_ids" {
  description = "Raíz (r-...), OUs (ou-...) o cuentas (12 dígitos) donde se adjunta la política. La excepción es de alcance: dejá fuera de estos targets la OU o cuenta que necesita buckets públicos (gotcha: s3-policy-scope-is-the-exception)."
  type        = set(string)

  validation {
    condition     = length(var.target_ids) > 0
    error_message = "target_ids: al menos un target; sin attachment la política no aplica a nada."
  }

  validation {
    condition     = alltrue([for t in var.target_ids : can(regex("^(r-[0-9a-z]{4,32}|ou-[0-9a-z]{4,32}-[0-9a-z]{8,32}|[0-9]{12})$", t))])
    error_message = "target_ids: cada valor es el ID de una raíz, una OU o una cuenta."
  }
}

variable "tags" {
  description = "Tags comunes."
  type        = map(string)
  default     = {}
}
