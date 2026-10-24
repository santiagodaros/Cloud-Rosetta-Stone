output "secret_id" {
  description = "ID del secreto. Cargá la primera versión fuera de banda (gcloud secrets versions add) y referenciala por número, no por latest."
  value       = google_secret_manager_secret.this.secret_id
}

output "workload_service_account_email" {
  description = "Service account del workload; asignala al Cloud Run service, VM o pod."
  value       = google_service_account.app.email
}

output "subnet_self_link" {
  description = "Subnet con Private Google Access para el workload."
  value       = google_compute_subnetwork.workload.self_link
}

output "kms_key_id" {
  description = "Clave de Cloud KMS (CMEK) que cifra las versiones del secreto."
  value       = google_kms_crypto_key.secrets.id
}
