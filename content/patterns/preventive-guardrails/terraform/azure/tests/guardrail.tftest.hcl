# Tests sin credenciales ni recursos reales: mock_provider + command = plan.

mock_provider "azurerm" {}

variables {
  name                = "org"
  management_group_id = "/providers/Microsoft.Management/managementGroups/contoso"
}

run "denies_by_default_and_enforces" {
  command = plan

  assert {
    condition     = jsondecode(azurerm_management_group_policy_assignment.no_public_blob.parameters).effect.value == "deny"
    error_message = "El efecto por defecto tiene que ser deny: con audit la cuenta pública se crea igual."
  }

  assert {
    condition     = azurerm_management_group_policy_assignment.no_public_blob.enforce == true
    error_message = "La asignación tiene que aplicar el efecto por defecto (enforce = true)."
  }

  assert {
    condition     = azurerm_management_group_policy_assignment.no_public_blob.management_group_id == var.management_group_id
    error_message = "La asignación vive en el management group, no en una suscripción."
  }
}

run "rule_catches_anything_but_false" {
  command = plan

  assert {
    condition     = jsondecode(azurerm_policy_definition.no_public_blob.policy_rule).if.allOf[1].not.equals == "false" && jsondecode(azurerm_policy_definition.no_public_blob.policy_rule).if.allOf[1].not.field == "Microsoft.Storage/storageAccounts/allowBlobPublicAccess"
    error_message = "Es no conforme todo lo que no tenga allowBlobPublicAccess en false."
  }

  assert {
    condition     = jsondecode(azurerm_policy_definition.no_public_blob.policy_rule).then.effect == "[parameters('effect')]"
    error_message = "El efecto se toma del parámetro de la asignación."
  }
}

run "audit_and_dry_run_are_explicit" {
  command = plan

  variables {
    effect  = "audit"
    enforce = false
  }

  assert {
    condition     = jsondecode(azurerm_management_group_policy_assignment.no_public_blob.parameters).effect.value == "audit" && azurerm_management_group_policy_assignment.no_public_blob.enforce == false
    error_message = "audit y DoNotEnforce son decisiones explícitas del que despliega."
  }
}

run "exemption_expires_and_leaves_a_record" {
  command = plan

  variables {
    exemptions = {
      static-site = {
        subscription_id = "/subscriptions/00000000-0000-0000-0000-000000000001"
        expires_on      = "2027-03-31T23:59:00Z"
        reason          = "Sitio estático público"
        requested_by    = "equipo-web"
        approved_by     = "seguridad"
        ticket          = "SEC-123"
      }
    }
  }

  assert {
    condition     = azurerm_subscription_policy_exemption.this["static-site"].expires_on == "2027-03-31T23:59:00Z" && azurerm_subscription_policy_exemption.this["static-site"].exemption_category == "Waiver"
    error_message = "La excepción es un Waiver con vencimiento."
  }

  assert {
    condition     = jsondecode(azurerm_subscription_policy_exemption.this["static-site"].metadata).approvedBy == "seguridad" && jsondecode(azurerm_subscription_policy_exemption.this["static-site"].metadata).ticketRef == "SEC-123"
    error_message = "La excepción guarda quién la aprobó y el ticket."
  }
}

run "exemption_without_a_valid_expiry_is_rejected" {
  command = plan

  variables {
    exemptions = {
      forever = {
        subscription_id = "/subscriptions/00000000-0000-0000-0000-000000000001"
        expires_on      = "nunca"
        reason          = "x"
        requested_by    = "a"
        approved_by     = "b"
        ticket          = "T-1"
      }
    }
  }

  expect_failures = [var.exemptions]
}

run "short_management_group_name_is_rejected" {
  command = plan

  variables {
    management_group_id = "contoso"
  }

  expect_failures = [var.management_group_id]
}
