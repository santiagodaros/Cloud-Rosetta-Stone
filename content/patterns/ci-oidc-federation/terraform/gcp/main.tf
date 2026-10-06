# Despliegue desde CI sin secretos — GCP
#
# Workload Identity Pool + provider OIDC de GitHub con una condición CEL sobre
# IDs inmutables, y una service account de despliegue que solo puede
# impersonar el principalSet de ese repositorio.

locals {
  # Las cuatro APIs que pide la guía de Google para pipelines.
  apis = ["iam.googleapis.com", "cloudresourcemanager.googleapis.com", "iamcredentials.googleapis.com", "sts.googleapis.com"]

  envs_cel = join(", ", [for e in sort(tolist(var.environments)) : "'${e}'"])

  # Sin condición, cualquier repo de GitHub podría obtener tokens: el issuer es compartido.
  attribute_condition = "assertion.repository_owner_id == '${var.github.owner_id}' && assertion.repository_id == '${var.github.repository_id}' && assertion.environment in [${local.envs_cel}]"

  attribute_mapping = {
    "google.subject"                = "assertion.sub"
    "attribute.repository_id"       = "assertion.repository_id"
    "attribute.repository_owner_id" = "assertion.repository_owner_id"
    "attribute.environment"         = "assertion.environment"
  }
}

resource "google_project_service" "required" {
  for_each = toset(local.apis)

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = var.pool_id
  display_name              = "GitHub Actions"
  description               = "Tokens OIDC de GitHub Actions"

  depends_on = [google_project_service.required]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  #checkov:skip=CKV_GCP_125:El check solo reconoce condiciones sobre assertion.sub con nombres; esta condición usa repository_owner_id y repository_id (inmutables), que es lo que recomienda Google.
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-oidc"
  display_name                       = "GitHub OIDC"

  attribute_mapping   = local.attribute_mapping
  attribute_condition = local.attribute_condition

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "deploy" {
  project      = var.project_id
  account_id   = "gha-deploy"
  display_name = "GitHub Actions deploy"
}

# Solo el principalSet de este repositorio puede impersonar la SA.
resource "google_service_account_iam_member" "workload_identity_user" {
  service_account_id = google_service_account.deploy.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository_id/${var.github.repository_id}"
}

resource "google_project_iam_member" "deploy" {
  for_each = var.deploy_roles

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.deploy.email}"
}
