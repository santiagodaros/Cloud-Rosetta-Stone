variable "name" {
  description = "Prefijo para nombrar los recursos (ej. \"ingest-demo\")."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.name))
    error_message = "name: 3-20 caracteres, minúsculas, números o guiones."
  }
}

variable "storage_account_name" {
  description = "Nombre global único de la Storage Account (3-24, solo minúsculas y números)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "storage_account_name: 3-24 caracteres, solo minúsculas y números."
  }
}

variable "location" {
  description = "Región de Azure."
  type        = string
  default     = "eastus2"
}

variable "ttl_days" {
  description = "Días desde la creación tras los cuales se borra el blob."
  type        = number
  default     = 7

  validation {
    condition     = var.ttl_days >= 1 && floor(var.ttl_days) == var.ttl_days
    error_message = "ttl_days debe ser un entero >= 1."
  }
}

variable "object_prefix" {
  description = "Ruta dentro del contenedor a la que aplica el TTL (sin el nombre del contenedor)."
  type        = string
  default     = "incoming/"
}

variable "soft_delete_retention_days" {
  description = "Retención de soft delete. El costo efectivo del TTL es ttl_days + este valor (gotcha: soft-delete-keeps-capacity)."
  type        = number
  default     = 7

  validation {
    condition     = var.soft_delete_retention_days >= 1 && var.soft_delete_retention_days <= 365
    error_message = "soft_delete_retention_days debe estar entre 1 y 365."
  }
}

variable "vnet_address_space" {
  description = "Espacio de direcciones de la VNet del workload."
  type        = string
  default     = "10.10.0.0/16"
}

variable "endpoints_subnet_prefix" {
  description = "Prefijo de la subnet para Private Endpoints."
  type        = string
  default     = "10.10.1.0/24"
}

variable "tags" {
  description = "Tags aplicados a todos los recursos."
  type        = map(string)
  default     = {}
}
