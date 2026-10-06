# Tests sin credenciales ni recursos reales: mock_provider + command = plan.

mock_provider "google" {}

variables {
  project_id   = "demo-project"
  github       = { owner_id = 123, repository_id = 456 }
  environments = ["production", "staging"]
  deploy_roles = ["roles/run.developer"]
}

run "condition_uses_immutable_ids_and_environments" {
  command = plan

  assert {
    condition     = google_iam_workload_identity_pool_provider.github.attribute_condition == "assertion.repository_owner_id == '123' && assertion.repository_id == '456' && assertion.environment in ['production', 'staging']"
    error_message = "La condición tiene que acotar por owner_id, repository_id y environment."
  }

  assert {
    condition     = alltrue([for k in ["attribute.repository_id", "attribute.repository_owner_id", "attribute.environment"] : contains(keys(google_iam_workload_identity_pool_provider.github.attribute_mapping), k)])
    error_message = "Todo atributo usado en la condición o en el principalSet tiene que estar mapeado."
  }

  assert {
    condition     = google_iam_workload_identity_pool_provider.github.oidc[0].issuer_uri == "https://token.actions.githubusercontent.com"
    error_message = "El issuer tiene que ser el de GitHub Actions."
  }
}

run "only_the_repository_can_impersonate" {
  command = plan

  assert {
    condition     = google_service_account_iam_member.workload_identity_user.role == "roles/iam.workloadIdentityUser"
    error_message = "La impersonación se otorga con roles/iam.workloadIdentityUser sobre la SA."
  }

  assert {
    condition     = length(google_project_service.required) == 4
    error_message = "Faltan APIs: iam, cloudresourcemanager, iamcredentials y sts."
  }
}

run "rejects_primitive_roles" {
  command = plan

  variables {
    deploy_roles = ["roles/editor"]
  }

  expect_failures = [var.deploy_roles]
}

run "rejects_reserved_pool_prefix" {
  command = plan

  variables {
    pool_id = "gcp-github"
  }

  expect_failures = [var.pool_id]
}
