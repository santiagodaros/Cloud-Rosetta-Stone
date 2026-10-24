variable "name" {
  description = "Prefijo para nombrar los recursos (ej. \"app-secrets\")."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.name))
    error_message = "name: 3-20 caracteres, minúsculas, números o guiones."
  }
}

variable "region" {
  description = "Región del secreto, la clave KMS y el endpoint."
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "VPC donde corre el workload (y la función de rotación, si hay)."
  type        = string
}

variable "endpoint_subnet_ids" {
  description = "Subnets para las ENIs del interface endpoint de Secrets Manager (cada una factura por hora)."
  type        = list(string)

  validation {
    condition     = length(var.endpoint_subnet_ids) >= 1
    error_message = "endpoint_subnet_ids: al menos una subnet."
  }
}

variable "workload_cidrs" {
  description = "Rangos desde donde el workload (y la función de rotación) llaman al endpoint por HTTPS."
  type        = list(string)

  validation {
    condition     = length(var.workload_cidrs) >= 1 && !contains(var.workload_cidrs, "0.0.0.0/0")
    error_message = "workload_cidrs: al menos un rango, y no 0.0.0.0/0."
  }
}

variable "workload_service_principal" {
  description = "Servicio de AWS que asume el rol del workload (ecs-tasks.amazonaws.com, lambda.amazonaws.com, ec2.amazonaws.com)."
  type        = string
  default     = "ecs-tasks.amazonaws.com"
}

variable "recovery_window_in_days" {
  description = "Días que Secrets Manager espera antes de borrar el secreto (7 a 30; 0 fuerza el borrado sin recuperación)."
  type        = number
  default     = 30

  validation {
    condition     = var.recovery_window_in_days == 0 || (var.recovery_window_in_days >= 7 && var.recovery_window_in_days <= 30)
    error_message = "recovery_window_in_days: 0 o entre 7 y 30."
  }
}

variable "kms_deletion_window_in_days" {
  description = "Espera antes de borrar la clave KMS (7 a 30). Borrarla deja el secreto ilegible."
  type        = number
  default     = 30

  validation {
    condition     = var.kms_deletion_window_in_days >= 7 && var.kms_deletion_window_in_days <= 30
    error_message = "kms_deletion_window_in_days: entre 7 y 30."
  }
}

variable "rotation_lambda_arn" {
  description = "ARN de la función Lambda que rota el secreto. null = sin rotación automática. La función tiene que alcanzar el endpoint de Secrets Manager (gotcha: rotation-lambda-needs-private-path)."
  type        = string
  default     = null
}

variable "rotation_lambda_role_arn" {
  description = "ARN del rol de la función de rotación; se agrega a la política del endpoint para que pueda rotar por la red privada."
  type        = string
  default     = null
}

variable "rotation_days" {
  description = "Días entre rotaciones automáticas (solo si hay rotation_lambda_arn)."
  type        = number
  default     = 30

  validation {
    condition     = var.rotation_days >= 1
    error_message = "rotation_days: al menos 1."
  }
}

variable "tags" {
  description = "Tags comunes."
  type        = map(string)
  default     = {}
}
