variable "name" {
  description = "Prefijo para nombrar los recursos (ej. \"assets\")."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,16}$", var.name))
    error_message = "name: 3-16 caracteres, minúsculas y números (se usa también en el nombre de la Storage Account)."
  }
}

variable "location" {
  description = "Región de la Storage Account de origen y del grupo de recursos."
  type        = string
  default     = "eastus2"
}

variable "container_name" {
  description = "Contenedor de blobs con el contenido público (lectura anónima, alcanzable solo por el private endpoint de Front Door)."
  type        = string
  default     = "content"
}

variable "storage_account_name" {
  description = "Nombre global de la Storage Account (3-24 caracteres, minúsculas y números)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "storage_account_name: 3-24 caracteres, minúsculas y números."
  }
}

variable "custom_domain" {
  description = "Dominio propio para el endpoint (ej. \"cdn.example.com\"), con certificado administrado por Front Door. Null = solo el dominio *.azurefd.net. La validación del dominio (TXT en DNS) queda a cargo del dueño de la zona."
  type        = string
  default     = null
}

variable "waf_mode" {
  description = "Modo de la política WAF de Front Door: Prevention bloquea, Detection solo registra."
  type        = string
  default     = "Prevention"

  validation {
    condition     = contains(["Prevention", "Detection"], var.waf_mode)
    error_message = "waf_mode: Prevention o Detection."
  }
}

variable "tags" {
  description = "Tags comunes."
  type        = map(string)
  default     = {}
}
