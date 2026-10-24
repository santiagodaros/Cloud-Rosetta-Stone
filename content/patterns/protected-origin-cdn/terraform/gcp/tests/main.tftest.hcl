# Tests sin credenciales ni recursos reales: mock_provider + command = plan.

mock_provider "google" {}

variables {
  project_id           = "demo-project"
  project_number       = "123456789012"
  name                 = "assets-test"
  domains              = ["cdn.example.com"]
  signed_url_key_value = "aGVsbG8gd29ybGQgMTIzNA=="
}

run "bucket_is_private" {
  command = plan

  assert {
    condition     = google_storage_bucket.origin.public_access_prevention == "enforced"
    error_message = "El bucket de origen no puede ser público: con acceso público las URLs firmadas no protegen nada."
  }

  assert {
    condition     = google_storage_bucket.origin.uniform_bucket_level_access == true
    error_message = "El bucket usa acceso uniforme: los permisos viven solo en IAM."
  }
}

run "backend_bucket_has_cdn_and_signed_urls" {
  command = plan

  assert {
    condition     = google_compute_backend_bucket.this.enable_cdn == true
    error_message = "Sin Cloud CDN en el backend bucket, los objetos se sirven desde Cloud Storage y no desde el caché de CDN."
  }

  assert {
    condition     = google_compute_backend_bucket_signed_url_key.this.name == "key-1"
    error_message = "El backend bucket tiene una clave de URLs firmadas."
  }
}

run "cdn_service_account_reads_the_bucket" {
  command = plan

  assert {
    condition     = google_storage_bucket_iam_member.cdn_fill.member == "serviceAccount:service-123456789012@cloud-cdn-fill.iam.gserviceaccount.com"
    error_message = "Cloud CDN lee el bucket con su cuenta de servicio (service-<número>@cloud-cdn-fill...)."
  }

  assert {
    condition     = google_storage_bucket_iam_member.cdn_fill.role == "roles/storage.objectViewer"
    error_message = "La cuenta de servicio de Cloud CDN solo necesita lectura de objetos."
  }
}

run "frontend_is_https_with_modern_tls" {
  command = plan

  assert {
    condition     = google_compute_global_forwarding_rule.https.port_range == "443" && google_compute_global_forwarding_rule.https.load_balancing_scheme == "EXTERNAL_MANAGED"
    error_message = "El balanceador es el Application Load Balancer externo global, solo HTTPS."
  }

  assert {
    condition     = google_compute_ssl_policy.this.min_tls_version == "TLS_1_2"
    error_message = "La política TLS exige TLS 1.2 como mínimo."
  }
}

run "invalid_project_number_is_rejected" {
  command = plan

  variables {
    project_number = "demo-project"
  }

  expect_failures = [var.project_number]
}

run "invalid_signed_url_key_is_rejected" {
  command = plan

  variables {
    signed_url_key_value = "not a key"
  }

  expect_failures = [var.signed_url_key_value]
}
