# Tests sin credenciales ni recursos reales: mock_provider + command = plan.

mock_provider "google" {}

variables {
  parent = "organizations/123456789012"
}

run "enforces_the_constraint_on_the_parent" {
  command = plan

  assert {
    condition     = google_org_policy_policy.public_access_prevention.name == "organizations/123456789012/policies/storage.publicAccessPrevention"
    error_message = "La policy es de la constraint storage.publicAccessPrevention y vive en el parent."
  }

  assert {
    condition     = one(one(google_org_policy_policy.public_access_prevention.spec).rules).enforce == "TRUE"
    error_message = "La constraint tiene que estar enforced."
  }
}

run "folder_scope_is_accepted" {
  command = plan

  variables {
    parent = "folders/987654321"
  }

  assert {
    condition     = google_org_policy_policy.public_access_prevention.parent == "folders/987654321"
    error_message = "Se puede aplicar a una carpeta."
  }
}

run "exception_turns_the_constraint_off_in_one_project_only" {
  command = plan

  variables {
    exception_projects = {
      static-site = {
        project_number = "111111111111"
        reason         = "Sitio estático público"
        approved_by    = "seguridad"
        ticket         = "SEC-123"
      }
    }
  }

  assert {
    condition     = one(one(google_org_policy_policy.exception["static-site"].spec).rules).enforce == "FALSE" && google_org_policy_policy.exception["static-site"].parent == "projects/111111111111"
    error_message = "La excepción apaga la constraint en ese proyecto."
  }

  assert {
    condition     = one(one(google_org_policy_policy.public_access_prevention.spec).rules).enforce == "TRUE"
    error_message = "La política del parent no cambia por una excepción."
  }

  assert {
    condition     = output.exceptions["static-site"].ticket == "SEC-123" && output.exceptions["static-site"].approved_by == "seguridad"
    error_message = "La excepción deja motivo, aprobador y ticket en el output."
  }
}

run "exception_without_ticket_is_rejected" {
  command = plan

  variables {
    exception_projects = {
      sin-ticket = {
        project_number = "111111111111"
        reason         = "x"
        approved_by    = "seguridad"
        ticket         = ""
      }
    }
  }

  expect_failures = [var.exception_projects]
}

run "project_id_instead_of_number_is_rejected" {
  command = plan

  variables {
    exception_projects = {
      mal = {
        project_number = "mi-proyecto"
        reason         = "x"
        approved_by    = "seguridad"
        ticket         = "SEC-1"
      }
    }
  }

  expect_failures = [var.exception_projects]
}

run "malformed_parent_is_rejected" {
  command = plan

  variables {
    parent = "projects/123"
  }

  expect_failures = [var.parent]
}
