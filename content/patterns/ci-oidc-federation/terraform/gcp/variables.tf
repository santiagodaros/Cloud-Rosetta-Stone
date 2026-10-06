variable "project_id" {
  description = "Proyecto donde viven el pool y la service account de despliegue."
  type        = string
}

variable "region" {
  description = "Región por defecto del provider."
  type        = string
  default     = "us-central1"
}

variable "pool_id" {
  description = "ID del workload identity pool (4-32, minúsculas). Un pool borrado bloquea su ID ~30 días (gotcha: pool-soft-delete-30-days)."
  type        = string
  default     = "github"

  validation {
    condition     = can(regex("^[a-z0-9-]{4,32}$", var.pool_id)) && !startswith(var.pool_id, "gcp-")
    error_message = "pool_id: 4-32 caracteres [a-z0-9-], sin el prefijo reservado gcp-."
  }
}

variable "github" {
  description = <<-EOT
    Repositorio que puede desplegar. En GCP la condición se arma sobre los IDs numéricos (inmutables), no sobre
    los nombres: un nombre de org o repo reciclado no hereda la confianza.
  EOT
  type = object({
    owner_id      = number
    repository_id = number
  })
}

variable "environments" {
  description = "Environments de GitHub que pueden desplegar."
  type        = set(string)
  default     = ["production"]

  validation {
    condition     = length(var.environments) >= 1 && alltrue([for e in var.environments : can(regex("^[A-Za-z0-9_.-]+$", e))])
    error_message = "environments: al menos uno, solo letras, números, '.', '_' o '-'."
  }
}

variable "deploy_roles" {
  description = "Roles de proyecto que necesita el despliegue (mínimo privilegio)."
  type        = set(string)

  validation {
    condition     = length(setintersection(var.deploy_roles, ["roles/owner", "roles/editor", "roles/iam.serviceAccountUser", "roles/iam.serviceAccountTokenCreator"])) == 0
    error_message = "deploy_roles: nada de owner/editor ni roles que permitan actuar como otras service accounts a nivel proyecto."
  }
}
