output "bucket_url" {
  description = "URL gs:// del bucket."
  value       = google_storage_bucket.ingest.url
}

output "producer_service_account_email" {
  description = "Service Account que tiene que usar el workload productor."
  value       = google_service_account.producer.email
}
