variable "project_id" {
  description = "ID del proyecto de GCP."
  type        = string
}

variable "name" {
  description = "Prefijo para nombrar los recursos (ej. \"api-demo\")."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,19}$", var.name))
    error_message = "name: 3-20 caracteres, empieza con letra, minúsculas, números o guiones."
  }
}

variable "region" {
  description = "Región de GCP."
  type        = string
  default     = "us-central1"
}

variable "subnet_cidr" {
  description = "CIDR de la subnet usada por Direct VPC egress."
  type        = string
  default     = "10.60.0.0/24"
}

variable "psa_prefix_length" {
  description = "Tamaño del rango reservado para private services access (Cloud SQL)."
  type        = number
  default     = 20
}

variable "container_image" {
  description = "Imagen de la API (Artifact Registry)."
  type        = string
}

variable "container_port" {
  description = "Puerto en el que escucha la API."
  type        = number
  default     = 8080
}

variable "max_instances" {
  description = "Máximo de instancias de Cloud Run."
  type        = number
  default     = 10
}

variable "invoker_members" {
  description = "Principals con roles/run.invoker (ej. \"serviceAccount:caller@proyecto.iam.gserviceaccount.com\"). Gotcha: run-internal-is-not-auth."
  type        = set(string)
  default     = []

  validation {
    condition     = alltrue([for m in var.invoker_members : !contains(["allUsers", "allAuthenticatedUsers"], m)])
    error_message = "Una API privada no puede ser invocable por allUsers ni allAuthenticatedUsers."
  }
}

variable "db_tier" {
  description = "Tier de Cloud SQL (edición Enterprise)."
  type        = string
  default     = "db-custom-1-3840"
}

variable "database_name" {
  description = "Base de datos de la aplicación."
  type        = string
  default     = "app"
}

variable "deletion_protection" {
  description = "Protección contra borrado de Cloud SQL y Cloud Run."
  type        = bool
  default     = true
}

variable "labels" {
  description = "Labels aplicados a los recursos que los soportan."
  type        = map(string)
  default     = {}
}
