variable "name" {
  description = "Prefijo para nombrar los recursos (ej. \"egress-hub\")."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.name))
    error_message = "name: 3-20 caracteres, minúsculas, números o guiones."
  }
}

variable "location" {
  description = "Región del hub."
  type        = string
  default     = "eastus2"
}

variable "vnet_address_space" {
  description = "Espacio de direcciones de la VNet."
  type        = string
  default     = "10.20.0.0/16"
}

variable "firewall_subnet_prefix" {
  description = "Prefijo de AzureFirewallSubnet (/26 o mayor)."
  type        = string
  default     = "10.20.0.0/26"

  validation {
    condition     = tonumber(split("/", var.firewall_subnet_prefix)[1]) <= 26
    error_message = "firewall_subnet_prefix: AzureFirewallSubnet necesita una máscara /26 o mayor."
  }
}

variable "workload_subnet_prefix" {
  description = "Prefijo de la subnet privada de los workloads."
  type        = string
  default     = "10.20.1.0/24"
}

variable "allowed_fqdns" {
  description = "FQDN a los que los workloads pueden salir por HTTPS (admite comodines en reglas de aplicación)."
  type        = list(string)

  validation {
    condition     = length(var.allowed_fqdns) >= 1 && !contains(var.allowed_fqdns, "*")
    error_message = "allowed_fqdns: al menos un FQDN, y \"*\" abriría la salida a cualquier destino."
  }
}

variable "nat_sku_name" {
  description = "SKU del NAT Gateway: StandardV2 es zona-redundante; Standard es zonal (gotcha: nat-standard-zonal)."
  type        = string
  default     = "StandardV2"

  validation {
    condition     = contains(["Standard", "StandardV2"], var.nat_sku_name)
    error_message = "nat_sku_name: Standard o StandardV2."
  }
}

variable "nat_zone" {
  description = "Zona del NAT Gateway Standard (\"1\", \"2\" o \"3\"). Solo aplica con nat_sku_name = Standard; StandardV2 no lleva zonas."
  type        = string
  default     = null
}

variable "nat_public_ip_count" {
  description = "Cantidad de IPs públicas del NAT Gateway. Cada una es una IP más para el allowlist del tercero."
  type        = number
  default     = 1

  validation {
    condition     = var.nat_public_ip_count >= 1 && var.nat_public_ip_count <= 16
    error_message = "nat_public_ip_count: entre 1 y 16."
  }
}

variable "tags" {
  description = "Tags comunes."
  type        = map(string)
  default     = {}
}
