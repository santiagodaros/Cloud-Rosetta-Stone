variable "name" {
  description = "Prefijo para nombrar los recursos (ej. \"assets\")."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.name))
    error_message = "name: 3-20 caracteres, minúsculas, números o guiones."
  }
}

variable "region" {
  description = "Región del bucket de origen."
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Nombre global del bucket de origen. Null = \"<name>-origin-<account id>\"."
  type        = string
  default     = null
}

variable "kms_key_arn" {
  description = "CMK para cifrar el bucket (SSE-KMS). Null = SSE-S3. Con una CMK, su key policy tiene que permitir a la distribución (output distribution_arn); eso queda a cargo del dueño de la clave (gotcha: sse-kms-needs-key-policy)."
  type        = string
  default     = null
}

variable "aliases" {
  description = "Nombres de dominio alternativos de la distribución. Requiere acm_certificate_arn."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.aliases) == 0 || var.acm_certificate_arn != null
    error_message = "aliases: necesitan acm_certificate_arn."
  }
}

variable "acm_certificate_arn" {
  description = "Certificado de ACM para los aliases. Null = certificado por defecto de CloudFront (dominio *.cloudfront.net)."
  type        = string
  default     = null
}

variable "web_acl_arn" {
  description = "ARN de un web ACL de AWS WAF para la distribución. Null = sin WAF."
  type        = string
  default     = null
}

variable "access_log_bucket_domain" {
  description = "Dominio de un bucket (ya existente, p. ej. \"logs.s3.amazonaws.com\") para los logs de acceso de la distribución. Null = sin logs."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags comunes."
  type        = map(string)
  default     = {}
}
