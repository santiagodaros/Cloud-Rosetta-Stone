variable "project_id" {
  description = "Proyecto que aloja la VPC hub, los spokes de este ejemplo y los firewall endpoints."
  type        = string
}

variable "region" {
  description = "Región de las subnets."
  type        = string
  default     = "us-central1"
}

variable "name" {
  description = "Prefijo para nombrar los recursos (ej. \"hub\")."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,19}$", var.name))
    error_message = "name: 3-20 caracteres, empieza con letra, minúsculas, números o guiones."
  }
}

variable "hub_cidr" {
  description = "Rango de la subnet de la VPC hub."
  type        = string
  default     = "10.10.0.0/24"
}

variable "spokes" {
  description = "VPC spokes: nombre => rango de su subnet. Los rangos no pueden solaparse entre VPC peereadas."
  type = map(object({
    cidr = string
  }))
  default = {}
}

variable "firewall_zones" {
  description = "Zonas donde se crea un firewall endpoint y su asociación con cada VPC (gotcha: firewall-endpoint-zonal-per-vpc)."
  type        = list(string)

  validation {
    condition     = length(var.firewall_zones) >= 1 && length(var.firewall_zones) == length(distinct(var.firewall_zones))
    error_message = "firewall_zones: al menos una zona, sin repetir."
  }
}

variable "security_profile_group" {
  description = "Perfil de seguridad de Cloud NGFW (organizations/<id>/locations/global/securityProfileGroups/<nombre>), creado fuera del módulo porque vive en la organización. Si es null no se crean la política ni las reglas y el endpoint no inspecciona nada."
  type        = string
  default     = null
}

variable "inspected_cidrs" {
  description = "Destinos (egress) y orígenes (ingress) cuyo tráfico selecciona la regla de inspección."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
