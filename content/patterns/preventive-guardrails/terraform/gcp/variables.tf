variable "parent" {
  description = "Donde se aplica la constraint: \"organizations/<id>\" o \"folders/<id>\". Los proyectos y carpetas debajo la heredan."
  type        = string

  validation {
    condition     = can(regex("^(organizations|folders)/[0-9]+$", var.parent))
    error_message = "parent: \"organizations/<id numérico>\" o \"folders/<id numérico>\"."
  }
}

variable "exception_projects" {
  description = "Excepciones por proyecto (clave = nombre de la excepción). Apagan la constraint en el proyecto entero; los buckets con el setting enforced siguen protegidos (gotcha: exception-is-per-project-and-bucket-setting-wins). El motivo, quién aprobó y el ticket quedan en el output exceptions."
  type = map(object({
    project_number = string
    reason         = string
    approved_by    = string
    ticket         = string
  }))
  default = {}

  validation {
    condition     = alltrue([for e in values(var.exception_projects) : can(regex("^[0-9]+$", e.project_number))])
    error_message = "exception_projects: project_number es el número del proyecto, no su ID de texto."
  }

  validation {
    condition = alltrue([
      for e in values(var.exception_projects) :
      length(trimspace(e.reason)) > 0 && length(trimspace(e.approved_by)) > 0 && length(trimspace(e.ticket)) > 0
    ])
    error_message = "exception_projects: reason, approved_by y ticket no pueden estar vacíos."
  }
}
