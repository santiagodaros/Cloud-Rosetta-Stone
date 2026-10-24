variable "project_id" {
  description = "Proyecto de la VPC."
  type        = string
}

variable "region" {
  description = "Región del Cloud Router y del Cloud NAT."
  type        = string
  default     = "us-central1"
}

variable "name" {
  description = "Prefijo para nombrar los recursos (ej. \"egress-hub\")."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,19}$", var.name))
    error_message = "name: 3-20 caracteres, empieza con letra, minúsculas, números o guiones."
  }
}

variable "network_id" {
  description = "ID de la VPC (projects/<p>/global/networks/<n>)."
  type        = string
}

variable "subnetwork_self_links" {
  description = "Subnets (de la región) cuyo tráfico sale por Cloud NAT."
  type        = list(string)

  validation {
    condition     = length(var.subnetwork_self_links) >= 1
    error_message = "subnetwork_self_links: al menos una subnet."
  }
}

variable "allowed_fqdns" {
  description = "FQDN a los que se puede salir por HTTPS. Sin comodines ni dominios de primer nivel; evitá googleapis.com (gotcha: fqdn-objects-limits)."
  type        = list(string)

  validation {
    condition     = length(var.allowed_fqdns) >= 1 && length(var.allowed_fqdns) <= 100 && alltrue([for d in var.allowed_fqdns : !strcontains(d, "*")])
    error_message = "allowed_fqdns: entre 1 y 100 FQDN, sin comodines (los FQDN objects no los admiten)."
  }
}

variable "always_allowed_cidrs" {
  description = "Rangos de destino que se permiten siempre (rangos internos, y lo que el workload necesite fuera de la lista de FQDN). Sin ellos, el deny de egress los corta (gotcha: egress-allowed-by-default)."
  type        = list(string)
  default     = []
}

variable "nat_ip_count" {
  description = "Cantidad de IPs externas estáticas del NAT. Cada una es una IP más para el allowlist del tercero y se cobra por hora."
  type        = number
  default     = 1

  validation {
    condition     = var.nat_ip_count >= 1
    error_message = "nat_ip_count: al menos 1."
  }
}

variable "min_ports_per_vm" {
  description = "Puertos mínimos por VM (potencia de 2, al menos 32 con asignación dinámica) (gotcha: cloud-nat-ports-per-vm)."
  type        = number
  default     = 64

  validation {
    condition     = var.min_ports_per_vm >= 32 && contains([32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768, 65536], var.min_ports_per_vm)
    error_message = "min_ports_per_vm: potencia de 2, de 32 en adelante."
  }
}
