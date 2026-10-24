output "lb_ip_address" {
  description = "IP global del balanceador: los dominios apuntan acá."
  value       = google_compute_global_address.this.address
}

output "bucket_name" {
  description = "Bucket de origen, sin acceso público."
  value       = google_storage_bucket.origin.name
}

output "backend_bucket_name" {
  description = "Backend bucket con Cloud CDN; es el recurso donde se firman las URLs."
  value       = google_compute_backend_bucket.this.name
}
