# Tests sin credenciales ni recursos reales: mock_provider + command = plan.

mock_provider "aws" {}

variables {
  name       = "org"
  target_ids = ["ou-ab12-cdef3456", "123456789012"]
}

run "enables_all_four_block_public_access_settings" {
  command = plan

  assert {
    condition     = aws_organizations_policy.block_public_access.type == "S3_POLICY"
    error_message = "Tiene que ser una S3 policy: una SCP no mira la configuración del bucket."
  }

  assert {
    condition     = jsondecode(aws_organizations_policy.block_public_access.content).s3_attributes.public_access_block_configuration["@@assign"] == "all"
    error_message = "Con \"all\" se habilitan las cuatro opciones; \"none\" las deshabilitaría."
  }
}

run "attaches_to_every_target" {
  command = plan

  assert {
    condition     = toset(keys(aws_organizations_policy_attachment.this)) == toset(["ou-ab12-cdef3456", "123456789012"])
    error_message = "Hay un attachment por cada target."
  }
}

run "exception_is_scope_not_a_flag" {
  command = plan

  variables {
    target_ids = ["ou-ab12-cdef3456"]
  }

  assert {
    condition     = !contains(keys(aws_organizations_policy_attachment.this), "123456789012") && contains(keys(aws_organizations_policy_attachment.this), "ou-ab12-cdef3456")
    error_message = "Un target que no figura en target_ids queda fuera de la política."
  }
}

run "empty_targets_are_rejected" {
  command = plan

  variables {
    target_ids = []
  }

  expect_failures = [var.target_ids]
}

run "malformed_target_is_rejected" {
  command = plan

  variables {
    target_ids = ["mi-ou"]
  }

  expect_failures = [var.target_ids]
}
