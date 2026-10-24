variable "name" {
  description = "Prefijo para nombrar los recursos (ej. \"app-secrets\"). El nombre del vault (kv-<name>) es global: tiene que ser único."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.name))
    error_message = "name: 3-20 caracteres, minúsculas, números o guiones."
  }
}

variable "location" {
  description = "Región del vault, la VNet y el Private Endpoint (tienen que coincidir)."
  type        = string
  default     = "eastus2"
}

variable "vnet_address_space" {
  description = "Espacio de direcciones de la VNet de la aplicación."
  type        = string
  default     = "10.20.0.0/16"
}

variable "private_endpoint_subnet_prefix" {
  description = "Subnet para el Private Endpoint del vault."
  type        = string
  default     = "10.20.1.0/27"
}

variable "log_analytics_workspace_id" {
  description = "Workspace donde se envían los logs de auditoría (AuditEvent). Sin diagnostic setting no se guarda ningún log (gotcha: audit-needs-diagnostic-setting)."
  type        = string
}

variable "soft_delete_retention_days" {
  description = "Días de retención tras borrar. Solo se define al crear el vault y no se puede cambiar (gotcha: soft-delete-blocks-name-reuse)."
  type        = number
  default     = 90

  validation {
    condition     = var.soft_delete_retention_days >= 7 && var.soft_delete_retention_days <= 90
    error_message = "soft_delete_retention_days: entre 7 y 90 (gotcha: soft-delete-blocks-name-reuse)."
  }
}

variable "create_app_key" {
  description = "Crea una clave en el vault para cifrado propio de la aplicación. Es una operación de data plane: quien aplica tiene que llegar al vault por la red privada (gotcha: vault-keys-do-not-encrypt-its-secrets)."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags comunes."
  type        = map(string)
  default     = {}
}
