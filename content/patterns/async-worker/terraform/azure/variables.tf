variable "name" {
  description = "Prefijo para nombrar los recursos (ej. \"worker-demo\")."
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

variable "servicebus_namespace_name" {
  description = "Nombre global único del namespace de Service Bus."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{4,48}[a-zA-Z0-9]$", var.servicebus_namespace_name))
    error_message = "servicebus_namespace_name: 6-50 caracteres, empieza con letra."
  }
}

variable "storage_account_name" {
  description = "Nombre global único de la Storage Account de resultados."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "storage_account_name: 3-24 caracteres, solo minúsculas y números."
  }
}

variable "max_delivery_count" {
  description = "Entregas antes de mandar el mensaje a $DeadLetterQueue."
  type        = number
  default     = 10

  validation {
    condition     = var.max_delivery_count >= 1
    error_message = "max_delivery_count debe ser >= 1."
  }
}

variable "messages_per_execution" {
  description = "Mensajes en cola por ejecución del job (messageCount del scaler KEDA)."
  type        = number
  default     = 5
}

variable "max_executions" {
  description = "Máximo de ejecuciones concurrentes del job."
  type        = number
  default     = 10
}

variable "replica_timeout_seconds" {
  description = "Tiempo máximo de cada ejecución."
  type        = number
  default     = 300
}

variable "container_image" {
  description = "Imagen del worker: procesa un lote de mensajes y termina."
  type        = string
  default     = "mcr.microsoft.com/k8se/quickstart-jobs:latest"
}

variable "tags" {
  description = "Tags aplicados a todos los recursos."
  type        = map(string)
  default     = {}
}
