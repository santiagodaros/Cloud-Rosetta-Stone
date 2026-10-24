variable "name" {
  description = "Prefijo para nombrar los recursos (ej. \"egress-hub\")."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.name))
    error_message = "name: 3-20 caracteres, minúsculas, números o guiones."
  }
}

variable "region" {
  description = "Región de la VPC."
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "VPC que ya tiene un internet gateway y las subnets de abajo."
  type        = string
}

variable "az_config" {
  description = <<-EOT
    Una entrada por AZ, con el nombre de la AZ como clave:
    - public_subnet_id: subnet pública donde vive el NAT gateway de esa AZ.
    - firewall_subnet_id: subnet dedicada al firewall endpoint de esa AZ.
    - private_route_table_id: tabla de rutas de las subnets privadas de esa AZ (el módulo agrega 0.0.0.0/0).
    - public_route_table_id: tabla de rutas de la subnet pública de esa AZ (tiene que tener ya 0.0.0.0/0 al internet
      gateway; el módulo agrega la ruta de retorno hacia el firewall endpoint).
  EOT
  type = map(object({
    public_subnet_id       = string
    firewall_subnet_id     = string
    private_route_table_id = string
    public_route_table_id  = string
  }))

  validation {
    condition     = length(var.az_config) >= 2
    error_message = "az_config: al menos dos AZs; un solo NAT gateway para varias AZs es un punto único de falla (gotcha: nat-zonal-single-az)."
  }
}

variable "private_cidrs" {
  description = "CIDR de las subnets privadas: se usan como HOME_NET de la lista de dominios y en la ruta de retorno."
  type        = list(string)

  validation {
    condition     = length(var.private_cidrs) >= 1
    error_message = "private_cidrs: al menos un CIDR."
  }
}

variable "allowed_domains" {
  description = "Dominios permitidos. Un punto inicial (\".example.com\") incluye el dominio y todos sus subdominios."
  type        = list(string)

  validation {
    condition     = length(var.allowed_domains) >= 1
    error_message = "allowed_domains: al menos un dominio."
  }
}

variable "rule_group_capacity" {
  description = "Capacidad de la regla stateful de dominios. No se puede cambiar sin reemplazar el rule group."
  type        = number
  default     = 100
}

variable "delete_protection" {
  description = "Protege el firewall contra borrado."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags comunes (se aplican como default_tags)."
  type        = map(string)
  default     = {}
}
