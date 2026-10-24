# Guardrail preventivo — GCP
#
# La constraint storage.publicAccessPrevention en true sobre una organización o carpeta; la heredan
# todos los proyectos de abajo. Las excepciones son una policy en el proyecto que la apaga.

# Las políticas existentes con allUsers no se borran: quedan en su lugar pero anuladas, y vuelven a
# valer si la constraint se apaga (gotcha: existing-public-grants-are-overridden-not-removed).
resource "google_org_policy_policy" "public_access_prevention" {
  name   = "${var.parent}/policies/storage.publicAccessPrevention"
  parent = var.parent

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}

# La excepción es por proyecto y no hay dry-run para esta constraint
# (gotcha: exception-is-per-project-and-bucket-setting-wins, no-dry-run-for-public-access-prevention).
resource "google_org_policy_policy" "exception" {
  for_each = var.exception_projects

  name   = "projects/${each.value.project_number}/policies/storage.publicAccessPrevention"
  parent = "projects/${each.value.project_number}"

  spec {
    rules {
      enforce = "FALSE"
    }
  }
}
