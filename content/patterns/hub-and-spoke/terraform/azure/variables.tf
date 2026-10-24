variable "name" {
  description = "Prefijo para nombrar los recursos (ej. \"hub\")."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.name))
    error_message = "name: 3-20 caracteres, minúsculas, números o guiones."
  }
}

variable "location" {
  description = "Región del hub. Un hub por región; los spokes de esa región se peerean a él."
  type        = string
  default     = "eastus2"
}

variable "hub_address_space" {
  description = "Espacio de direcciones de la VNet hub."
  type        = string
  default     = "10.10.0.0/16"
}

variable "firewall_subnet_prefix" {
  description = "Prefijo de AzureFirewallSubnet (/26 o más grande)."
  type        = string
  default     = "10.10.0.0/26"

  validation {
    condition     = tonumber(split("/", var.firewall_subnet_prefix)[1]) <= 26
    error_message = "firewall_subnet_prefix: /26 o más grande (gotcha: firewall-subnet-name-size-no-nsg)."
  }
}

variable "firewall_sku_tier" {
  description = "SKU del firewall y de su policy. Basic no está cubierto por este módulo."
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Premium"], var.firewall_sku_tier)
    error_message = "firewall_sku_tier: Standard o Premium."
  }
}

variable "spokes" {
  description = "Spokes de la misma región que el hub: nombre => espacio de direcciones. Cada uno recibe una VNet, un peering y una UDR hacia el firewall."
  type = map(object({
    address_space = string
  }))
  default = {}
}

variable "enable_gateway_transit" {
  description = "Los spokes usan el gateway del hub. Requiere que el hub tenga un gateway y que los spokes no tengan el suyo (gotcha: gateway-transit-flags)."
  type        = bool
  default     = false
}

variable "allow_spoke_to_spoke" {
  description = "Permite en la policy el tráfico entre los spokes. Por defecto el firewall lo inspecciona y lo bloquea."
  type        = bool
  default     = false
}

variable "allowed_egress_fqdns" {
  description = "FQDN HTTPS que los spokes pueden alcanzar hacia internet. Vacío = ninguno."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags comunes."
  type        = map(string)
  default     = {}
}
