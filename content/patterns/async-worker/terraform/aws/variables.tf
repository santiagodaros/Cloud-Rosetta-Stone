variable "name" {
  description = "Prefijo para nombrar los recursos (ej. \"worker-demo\")."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.name))
    error_message = "name: 3-20 caracteres, minúsculas, números o guiones."
  }
}

variable "region" {
  description = "Región de AWS."
  type        = string
  default     = "us-east-1"
}

variable "results_bucket_name" {
  description = "Nombre global único del bucket de resultados."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.results_bucket_name))
    error_message = "results_bucket_name: 3-63 caracteres, minúsculas, números, puntos o guiones."
  }
}

variable "image_uri" {
  description = "Imagen de la función en ECR."
  type        = string
}

variable "function_timeout_seconds" {
  description = "Timeout de la Lambda. El visibility timeout de la cola se fija en 6× este valor (gotcha: visibility-timeout-6x)."
  type        = number
  default     = 60

  validation {
    condition     = var.function_timeout_seconds >= 1 && var.function_timeout_seconds <= 900
    error_message = "function_timeout_seconds: entre 1 y 900 (límite de Lambda)."
  }
}

variable "max_receive_count" {
  description = "Entregas antes de mandar el mensaje a la DLQ."
  type        = number
  default     = 5
}

variable "batch_size" {
  description = "Mensajes por invocación."
  type        = number
  default     = 10
}

variable "max_concurrency" {
  description = "Invocaciones concurrentes máximas disparadas por la cola (gotcha: max-concurrency-protects-downstream)."
  type        = number
  default     = 10

  validation {
    condition     = var.max_concurrency >= 2
    error_message = "maximum_concurrency de un event source mapping de SQS es como mínimo 2."
  }
}

variable "results_ttl_days" {
  description = "Días que se conservan los resultados."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags aplicados a todos los recursos."
  type        = map(string)
  default     = {}
}
