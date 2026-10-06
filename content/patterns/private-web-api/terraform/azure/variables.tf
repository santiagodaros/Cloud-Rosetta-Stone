variable "name" {
  description = "Prefijo para nombrar los recursos (ej. \"api-demo\")."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.name))
    error_message = "name: 3-20 caracteres, minúsculas, números o guiones."
  }
}

variable "location" {
  description = "Región de Azure."
  type        = string
  default     = "eastus2"
}

variable "postgres_server_name" {
  description = "Nombre global único del servidor PostgreSQL (3-63, minúsculas, números y guiones)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.postgres_server_name))
    error_message = "postgres_server_name: 3-63 caracteres, minúsculas, números o guiones."
  }
}

variable "postgres_sku" {
  description = "SKU de PostgreSQL Flexible Server."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "database_name" {
  description = "Base de datos de la aplicación."
  type        = string
  default     = "app"
}

variable "entra_admin" {
  description = "Administrador Entra de PostgreSQL (recomendado: un grupo). Es quien ejecuta el SQL que crea el rol de la app."
  type = object({
    object_id      = string
    principal_name = string
    principal_type = string
  })

  validation {
    condition     = contains(["Group", "User", "ServicePrincipal"], var.entra_admin.principal_type)
    error_message = "principal_type: Group, User o ServicePrincipal."
  }
}

variable "container_image" {
  description = "Imagen de la API."
  type        = string
  default     = "mcr.microsoft.com/k8se/quickstart:latest"
}

variable "container_port" {
  description = "Puerto en el que escucha la API."
  type        = number
  default     = 80
}

variable "vnet_address_space" {
  description = "Espacio de direcciones de la VNet."
  type        = string
  default     = "10.40.0.0/16"
}

variable "aca_subnet_prefix" {
  description = "Subnet dedicada al environment (mínimo /27 con workload profiles; no se puede agrandar después)."
  type        = string
  default     = "10.40.0.0/24"
}

variable "endpoints_subnet_prefix" {
  description = "Subnet para Private Endpoints."
  type        = string
  default     = "10.40.1.0/24"
}

variable "max_replicas" {
  description = "Máximo de réplicas de la API."
  type        = number
  default     = 10
}

variable "tags" {
  description = "Tags aplicados a todos los recursos."
  type        = map(string)
  default     = {}
}
