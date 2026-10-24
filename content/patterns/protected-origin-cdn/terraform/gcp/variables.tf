variable "project_id" {
  description = "Proyecto que aloja el bucket, el backend bucket y el balanceador."
  type        = string
}

variable "region" {
  description = "Región por defecto del provider. Los recursos de este patrón son globales."
  type        = string
  default     = "us-central1"
}

variable "project_number" {
  description = "Número (no ID) del proyecto: arma la cuenta de servicio de Cloud CDN, service-<número>@cloud-cdn-fill.iam.gserviceaccount.com (gotcha: cdn-service-account-appears-with-first-key)."
  type        = string

  validation {
    condition     = can(regex("^[0-9]+$", var.project_number))
    error_message = "project_number: el número del proyecto, solo dígitos."
  }
}

variable "name" {
  description = "Prefijo para nombrar los recursos (ej. \"assets\")."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,19}$", var.name))
    error_message = "name: 3-20 caracteres, empieza con letra, minúsculas, números o guiones."
  }
}

variable "bucket_location" {
  description = "Ubicación del bucket de origen. Una multi-región (ej. \"US\") replica los objetos entre regiones."
  type        = string
  default     = "US"
}

variable "domains" {
  description = "Dominios del certificado administrado de Google para el balanceador. El DNS de cada uno tiene que apuntar a la IP del output lb_ip_address."
  type        = list(string)

  validation {
    condition     = length(var.domains) >= 1
    error_message = "domains: al menos un dominio para el certificado."
  }
}

variable "signed_url_key_name" {
  description = "Nombre de la clave de URLs firmadas."
  type        = string
  default     = "key-1"
}

variable "signed_url_key_value" {
  description = "Clave de URLs firmadas: 128 bits aleatorios codificados en base64url. Va al estado de Terraform; generala fuera del módulo y rotala."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[A-Za-z0-9_-]{22}={0,2}$", var.signed_url_key_value))
    error_message = "signed_url_key_value: 16 bytes en base64url (22 caracteres, con padding opcional)."
  }
}

variable "signed_url_cache_max_age_sec" {
  description = "Tiempo máximo que Cloud CDN cachea respuestas a pedidos firmados sin revalidar (gotcha: signed-url-responses-ignore-cache-control)."
  type        = number
  default     = 3600
}
