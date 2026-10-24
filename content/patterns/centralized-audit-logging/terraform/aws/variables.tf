variable "name" {
  description = "Prefijo para nombrar el bucket y la clave KMS (ej. \"audit\")."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.name))
    error_message = "name: 3-20 caracteres, minúsculas, números o guiones."
  }
}

variable "region" {
  description = "Región de la clave KMS y home Region del trail. Si es una región opt-in, los miembros tienen que habilitarla (gotcha: opt-in-home-region)."
  type        = string
  default     = "us-east-1"
}

variable "organization_id" {
  description = "ID de la organización (o-xxxxxxxxxx): el prefijo del bucket para los logs de las cuentas miembro."
  type        = string

  validation {
    condition     = can(regex("^o-[a-z0-9]{10,32}$", var.organization_id))
    error_message = "organization_id: tiene que tener el formato o-xxxxxxxxxx."
  }
}

variable "management_account_id" {
  description = "Cuenta que crea el trail (management o administrador delegado). Va en la aws:SourceArn del bucket y de la clave (gotcha: org-bucket-policy-needs-org-statement)."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.management_account_id))
    error_message = "management_account_id: 12 dígitos."
  }
}

variable "management_role_arn" {
  description = "Rol que el provider aws.management asume para crear el trail. Null = usa las credenciales del entorno."
  type        = string
  default     = null
}

variable "trail_name" {
  description = "Nombre del trail de organización."
  type        = string
  default     = "organization-audit"
}

variable "log_retention_days" {
  description = "Días que el bucket conserva los logs antes de expirarlos."
  type        = number
  default     = 365

  validation {
    condition     = var.log_retention_days >= 1 && floor(var.log_retention_days) == var.log_retention_days
    error_message = "log_retention_days: un entero de 1 o más."
  }
}

variable "reader_role_arns" {
  description = "Roles de la cuenta de log archive que pueden leer los logs y descifrarlos. Por defecto solo la cuenta de management los lee (gotcha: org-bucket-policy-needs-org-statement)."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags de todos los recursos."
  type        = map(string)
  default     = {}
}
