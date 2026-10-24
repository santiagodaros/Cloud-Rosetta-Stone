# Origen protegido detrás de CDN — GCP
#
# Bucket privado detrás de un backend bucket con Cloud CDN, publicado por un Application Load Balancer
# externo global. Los pedidos se firman (URLs firmadas) y Cloud CDN lee el bucket con su propia cuenta de
# servicio; el bucket no tiene permisos públicos.

# --- Origen -----------------------------------------------------------------------

# Sin allUsers ni allAuthenticatedUsers: con acceso público las URLs firmadas no protegen nada
# (gotcha: public-bucket-defeats-signed-urls).
resource "google_storage_bucket" "origin" {
  #checkov:skip=CKV_GCP_62:El bucket destino de los logs de acceso no se crea en este módulo (decisión de cada equipo).
  name                        = "${var.name}-origin-${var.project_id}"
  location                    = var.bucket_location
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }
}

# --- CDN: backend bucket con URLs firmadas ----------------------------------------

resource "google_compute_backend_bucket" "this" {
  name        = "${var.name}-backend"
  bucket_name = google_storage_bucket.origin.name
  enable_cdn  = true

  cdn_policy {
    cache_mode                   = "CACHE_ALL_STATIC"
    signed_url_cache_max_age_sec = var.signed_url_cache_max_age_sec
  }
}

# Con la primera clave aparece la cuenta de servicio de Cloud CDN
# (gotcha: cdn-service-account-appears-with-first-key).
resource "google_compute_backend_bucket_signed_url_key" "this" {
  name           = var.signed_url_key_name
  key_value      = var.signed_url_key_value
  backend_bucket = google_compute_backend_bucket.this.name
}

# Cloud CDN lee el bucket privado con su cuenta de servicio, no con allUsers
# (gotcha: cdn-service-account-appears-with-first-key).
resource "google_storage_bucket_iam_member" "cdn_fill" {
  bucket = google_storage_bucket.origin.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:service-${var.project_number}@cloud-cdn-fill.iam.gserviceaccount.com"

  depends_on = [google_compute_backend_bucket_signed_url_key.this]
}

# --- Balanceador y certificado -----------------------------------------------------

resource "google_compute_global_address" "this" {
  name = "${var.name}-ip"
}

resource "google_compute_managed_ssl_certificate" "this" {
  name = "${var.name}-cert"

  managed {
    domains = var.domains
  }
}

resource "google_compute_ssl_policy" "this" {
  name            = "${var.name}-tls"
  profile         = "MODERN"
  min_tls_version = "TLS_1_2"
}

resource "google_compute_url_map" "this" {
  name            = "${var.name}-urlmap"
  default_service = google_compute_backend_bucket.this.id
}

resource "google_compute_target_https_proxy" "this" {
  name             = "${var.name}-https-proxy"
  url_map          = google_compute_url_map.this.id
  ssl_certificates = [google_compute_managed_ssl_certificate.this.id]
  ssl_policy       = google_compute_ssl_policy.this.id
}

resource "google_compute_global_forwarding_rule" "https" {
  name                  = "${var.name}-https"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address            = google_compute_global_address.this.id
  ip_protocol           = "TCP"
  port_range            = "443"
  target                = google_compute_target_https_proxy.this.id
}
