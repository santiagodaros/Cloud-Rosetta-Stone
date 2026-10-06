output "jobs_topic" {
  description = "Topic al que publican los productores (necesitan roles/pubsub.publisher)."
  value       = google_pubsub_topic.jobs.id
}

output "dead_letter_subscription" {
  description = "Suscripción pull para inspeccionar y reprocesar mensajes fallidos."
  value       = google_pubsub_subscription.dead_letter.id
}

output "results_bucket" {
  description = "Bucket de resultados."
  value       = google_storage_bucket.results.url
}
