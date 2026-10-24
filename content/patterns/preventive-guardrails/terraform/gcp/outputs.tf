output "policy_name" {
  description = "Nombre de la organization policy que aplica la constraint."
  value       = google_org_policy_policy.public_access_prevention.name
}

output "exceptions" {
  description = "Excepciones vigentes: proyecto, motivo, quién aprobó y ticket. Revisalas con regularidad: cada una deja los allUsers existentes en vigor."
  value = {
    for k, e in var.exception_projects : k => {
      project_number = e.project_number
      reason         = e.reason
      approved_by    = e.approved_by
      ticket         = e.ticket
    }
  }
}
