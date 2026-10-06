variable "project_id" {
  description = "ID del proyecto de GCP."
  type        = string
}

variable "name" {
  description = "Prefijo para nombrar los recursos (ej. \"worker-demo\")."
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

variable "results_bucket_name" {
  description = "Nombre global único del bucket de resultados."
  type        = string
}

variable "container_image" {
  description = "Imagen del worker (responde 2xx cuando procesó el mensaje)."
  type        = string
}

variable "ack_deadline_seconds" {
  description = "Ack deadline de la suscripción push; también es el timeout del servicio (gotcha: push-ack-deadline)."
  type        = number
  default     = 60

  validation {
    condition     = var.ack_deadline_seconds >= 10 && var.ack_deadline_seconds <= 600
    error_message = "ack_deadline_seconds: entre 10 y 600."
  }
}

variable "max_delivery_attempts" {
  description = "Intentos antes de reenviar al dead-letter topic (Pub/Sub: 5 a 100)."
  type        = number
  default     = 5

  validation {
    condition     = var.max_delivery_attempts >= 5 && var.max_delivery_attempts <= 100
    error_message = "max_delivery_attempts: entre 5 y 100."
  }
}

variable "max_instances" {
  description = "Máximo de instancias del worker."
  type        = number
  default     = 10
}

variable "results_ttl_days" {
  description = "Días que se conservan los resultados."
  type        = number
  default     = 30
}

variable "labels" {
  description = "Labels aplicados a los recursos que los soportan."
  type        = map(string)
  default     = {}
}
