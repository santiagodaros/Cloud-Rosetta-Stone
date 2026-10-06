variable "project_id" {
  description = "Proyecto host de la VPC hub."
  type        = string
}

variable "region" {
  description = "Región del Cloud Router y de la VPN/Interconnect."
  type        = string
  default     = "us-central1"
}

variable "name" {
  description = "Prefijo para nombrar los recursos (ej. \"dns-hub\")."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,19}$", var.name))
    error_message = "name: 3-20 caracteres, empieza con letra, minúsculas, números o guiones."
  }
}

variable "network_id" {
  description = "ID de la VPC hub (projects/<p>/global/networks/<n>), la que tiene la VPN o el Interconnect."
  type        = string
}

variable "onprem_dns_servers" {
  description = "IPs de los DNS on-premises."
  type        = list(string)

  validation {
    condition     = length(var.onprem_dns_servers) >= 1
    error_message = "onprem_dns_servers: al menos uno."
  }
}

variable "onprem_domain" {
  description = "Dominio corporativo que se reenvía a on-premises."
  type        = string
  default     = "corp.example.com"
}

variable "private_zone_name" {
  description = "Zona privada que on-premises tiene que resolver."
  type        = string
  default     = "gcp.example.internal"
}

variable "router_asn" {
  description = "ASN privado del Cloud Router que habla BGP con on-premises."
  type        = number
  default     = 64514
}
