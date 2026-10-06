# Tests sin credenciales ni recursos reales: mock_provider + command = plan.

mock_provider "google" {}

variables {
  project_id      = "letra-chica-test"
  name            = "api-test"
  container_image = "us-docker.pkg.dev/letra-chica-test/api/api:1.0.0"
}

run "nothing_is_public" {
  command = plan

  assert {
    condition     = google_cloud_run_v2_service.api.ingress == "INGRESS_TRAFFIC_INTERNAL_ONLY"
    error_message = "Cloud Run tiene que tener ingress interno."
  }

  assert {
    condition     = google_sql_database_instance.this.settings[0].ip_configuration[0].ipv4_enabled == false
    error_message = "Cloud SQL no puede tener IP pública."
  }

  assert {
    condition     = google_sql_database_instance.this.settings[0].connector_enforcement == "REQUIRED"
    error_message = "Las conexiones tienen que pasar por connectors."
  }
}

run "database_uses_iam_auth" {
  command = plan

  assert {
    condition     = contains([for f in google_sql_database_instance.this.settings[0].database_flags : "${f.name}=${f.value}"], "cloudsql.iam_authentication=on")
    error_message = "Falta el flag cloudsql.iam_authentication=on."
  }

  assert {
    condition     = google_sql_user.api.type == "CLOUD_IAM_SERVICE_ACCOUNT"
    error_message = "El usuario de la app tiene que ser IAM, no de contraseña."
  }

  assert {
    condition     = toset(keys(google_project_iam_member.api)) == toset(["roles/cloudsql.client", "roles/cloudsql.instanceUser"])
    error_message = "La SA necesita cloudsql.client e instanceUser."
  }
}

run "app_scales_to_zero_and_egresses_privately" {
  command = plan

  assert {
    condition     = google_cloud_run_v2_service.api.template[0].scaling[0].min_instance_count == 0
    error_message = "La API debería escalar a cero."
  }

  assert {
    condition     = google_cloud_run_v2_service.api.template[0].vpc_access[0].egress == "PRIVATE_RANGES_ONLY"
    error_message = "El tráfico a rangos privados tiene que salir por la VPC."
  }
}

run "rejects_public_invoker" {
  command = plan

  variables {
    invoker_members = ["allUsers"]
  }

  expect_failures = [var.invoker_members]
}
