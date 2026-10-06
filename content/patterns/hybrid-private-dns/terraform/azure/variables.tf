variable "name" {
  description = "Prefijo para nombrar los recursos (ej. \"dns-hub\")."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.name))
    error_message = "name: 3-20 caracteres, minúsculas, números o guiones."
  }
}

variable "location" {
  description = "Región del hub. El resolver y los ruleset links solo funcionan con VNets de la misma región."
  type        = string
  default     = "eastus2"
}

variable "hub_address_space" {
  description = "Espacio de direcciones de la VNet hub."
  type        = string
  default     = "10.10.0.0/16"
}

variable "inbound_subnet_prefix" {
  description = "Subnet dedicada al inbound endpoint (/28 a /24)."
  type        = string
  default     = "10.10.0.0/28"

  validation {
    condition     = tonumber(split("/", var.inbound_subnet_prefix)[1]) >= 24 && tonumber(split("/", var.inbound_subnet_prefix)[1]) <= 28
    error_message = "inbound_subnet_prefix: entre /28 y /24 (gotcha: resolver-dedicated-subnets)."
  }
}

variable "outbound_subnet_prefix" {
  description = "Subnet dedicada al outbound endpoint (/28 a /24)."
  type        = string
  default     = "10.10.0.16/28"

  validation {
    condition     = tonumber(split("/", var.outbound_subnet_prefix)[1]) >= 24 && tonumber(split("/", var.outbound_subnet_prefix)[1]) <= 28
    error_message = "outbound_subnet_prefix: entre /28 y /24 (gotcha: resolver-dedicated-subnets)."
  }
}

variable "private_zone_name" {
  description = "Zona privada de Azure que on-premises tiene que resolver (puede ser una privatelink.*)."
  type        = string
  default     = "azure.example.internal"
}

variable "onprem_domain" {
  description = "Dominio corporativo que se reenvía a on-premises."
  type        = string
  default     = "corp.example.com"
}

variable "onprem_dns_servers" {
  description = "IPs de los DNS on-premises (alcanzables por VPN/ExpressRoute)."
  type        = list(string)

  validation {
    condition     = length(var.onprem_dns_servers) >= 1 && length(var.onprem_dns_servers) <= 6 && !contains(var.onprem_dns_servers, "168.63.129.16")
    error_message = "onprem_dns_servers: 1 a 6 IPs, y 168.63.129.16 no se acepta como destino de una regla."
  }
}

variable "onprem_cidrs" {
  description = "Rangos on-premises que consultan el inbound endpoint."
  type        = list(string)
}

variable "spoke_vnet_ids" {
  description = "VNets spoke (misma región) que usan el ruleset. No incluyas el hub: el ruleset reenvía la zona privada al inbound endpoint del hub."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags comunes."
  type        = map(string)
  default     = {}
}
