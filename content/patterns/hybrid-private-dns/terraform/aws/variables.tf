variable "name" {
  description = "Prefijo para nombrar los recursos (ej. \"dns-hub\")."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.name))
    error_message = "name: 3-20 caracteres, minúsculas, números o guiones."
  }
}

variable "region" {
  description = "Región del hub."
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "VPC hub (la que tiene la VPN o el Direct Connect)."
  type        = string
}

variable "endpoint_subnet_ids" {
  description = "Subnets para las ENIs de los endpoints, en al menos dos AZs distintas."
  type        = list(string)

  validation {
    condition     = length(var.endpoint_subnet_ids) >= 2 && length(var.endpoint_subnet_ids) <= 6
    error_message = "endpoint_subnet_ids: entre 2 y 6 (Resolver exige al menos dos IPs por endpoint)."
  }
}

variable "onprem_cidrs" {
  description = "Rangos on-premises que consultan el inbound endpoint y donde viven los DNS destino."
  type        = list(string)
}

variable "onprem_dns_servers" {
  description = "IPs de los DNS on-premises."
  type        = list(string)

  validation {
    condition     = length(var.onprem_dns_servers) >= 1 && length(var.onprem_dns_servers) <= 6
    error_message = "onprem_dns_servers: entre 1 y 6 (máximo de target IPs por regla)."
  }
}

variable "onprem_domain" {
  description = "Dominio corporativo que se reenvía a on-premises."
  type        = string
  default     = "corp.example.com"
}

variable "private_zone_name" {
  description = "Private hosted zone que on-premises tiene que resolver."
  type        = string
  default     = "aws.example.internal"
}

variable "spoke_vpc_ids" {
  description = "VPCs adicionales (misma cuenta y región) que usan la regla de reenvío. Para otras cuentas, compartila con AWS RAM."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags comunes."
  type        = map(string)
  default     = {}
}
