variable "name" {
  description = "Prefijo para nombrar los recursos (ej. \"hub\")."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.name))
    error_message = "name: 3-20 caracteres, minúsculas, números o guiones."
  }
}

variable "region" {
  description = "Región del Transit Gateway y de la VPC de inspección."
  type        = string
  default     = "us-east-1"
}

variable "azs" {
  description = "AZs de la VPC de inspección: un firewall endpoint y una subnet de attachment en cada una."
  type        = list(string)

  validation {
    condition     = length(var.azs) >= 2 && length(var.azs) == length(distinct(var.azs))
    error_message = "azs: al menos dos AZs distintas (gotcha: attachment-az-coverage)."
  }
}

variable "inspection_vpc_cidr" {
  description = "CIDR de la VPC de inspección."
  type        = string
  default     = "10.0.0.0/16"
}

variable "spokes" {
  description = "VPCs spoke: nombre => VPC y una subnet por AZ donde hay workloads (gotcha: attachment-az-coverage). La ruta 0.0.0.0/0 hacia el Transit Gateway en las subnets del spoke queda a cargo del dueño del spoke."
  type = map(object({
    vpc_id     = string
    subnet_ids = list(string)
  }))
  default = {}
}

variable "allowed_egress_domains" {
  description = "Dominios (HTTP_HOST y TLS_SNI) que el firewall deja pasar. Vacío = no se agrega regla stateful de dominios."
  type        = list(string)
  default     = []
}

variable "kms_key_arn" {
  description = "CMK para cifrar el firewall, su policy y el rule group. Null = clave propiedad de AWS."
  type        = string
  default     = null
}

variable "delete_protection" {
  description = "Protege el firewall contra borrado accidental. Ponelo en false para poder destruirlo (terraform destroy)."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags comunes."
  type        = map(string)
  default     = {}
}
