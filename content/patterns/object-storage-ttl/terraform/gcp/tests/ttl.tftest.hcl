# Tests sin credenciales ni recursos reales: mock_provider + command = plan.

mock_provider "google" {}

variables {
  project_id  = "rosetta-test"
  name        = "ingest-test"
  bucket_name = "ingest-test-bucket-001"
}

run "lifecycle_uses_ttl_and_prefix" {
  command = plan

  variables {
    ttl_days      = 3
    object_prefix = "incoming/"
  }

  assert {
    condition     = one([for r in google_storage_bucket.ingest.lifecycle_rule : one(r.condition).age if one(r.action).type == "Delete"]) == 3
    error_message = "La regla Delete no usa ttl_days."
  }

  assert {
    condition     = one([for r in google_storage_bucket.ingest.lifecycle_rule : one(r.condition).matches_prefix if one(r.action).type == "Delete"]) == tolist(["incoming/"])
    error_message = "El filtro tiene que usar object_prefix sin el nombre del bucket."
  }

  assert {
    condition     = length([for r in google_storage_bucket.ingest.lifecycle_rule : r if one(r.action).type == "AbortIncompleteMultipartUpload"]) == 1
    error_message = "Falta la regla AbortIncompleteMultipartUpload."
  }
}

run "bucket_is_private_and_soft_delete_is_explicit" {
  command = plan

  assert {
    condition     = google_storage_bucket.ingest.uniform_bucket_level_access && google_storage_bucket.ingest.public_access_prevention == "enforced"
    error_message = "UBLA y public access prevention tienen que estar activos."
  }

  assert {
    condition     = google_storage_bucket.ingest.soft_delete_policy[0].retention_duration_seconds == 0
    error_message = "Por default el módulo deshabilita soft delete para datos efímeros."
  }

  assert {
    condition     = google_compute_subnetwork.workloads.private_ip_google_access
    error_message = "La subnet necesita Private Google Access."
  }
}

run "producer_is_scoped_to_prefix" {
  command = plan

  assert {
    condition     = google_storage_bucket_iam_member.producer_create.role == "roles/storage.objectCreator"
    error_message = "El productor solo debe poder crear objetos."
  }

  assert {
    condition     = strcontains(google_storage_bucket_iam_member.producer_create.condition[0].expression, "/objects/incoming/")
    error_message = "La IAM Condition tiene que acotar al prefijo."
  }
}

run "ip_filter_is_opt_in" {
  command = plan

  variables {
    restrict_to_vpc = true
  }

  assert {
    condition     = google_storage_bucket.ingest.ip_filter[0].mode == "Enabled"
    error_message = "restrict_to_vpc tiene que activar bucket IP filtering."
  }
}

run "rejects_short_soft_delete" {
  command = plan

  variables {
    soft_delete_retention_seconds = 3600
  }

  expect_failures = [var.soft_delete_retention_seconds]
}
