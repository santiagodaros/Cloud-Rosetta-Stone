# Guardrail preventivo — Azure
#
# Una policy definition que deniega (o audita) storage accounts que permiten acceso anónimo a blobs,
# asignada en un management group, con exemptions por suscripción que vencen y dejan registro.

# La regla es la de la documentación de Azure Storage: no conforme todo lo que no tenga
# allowBlobPublicAccess en false. Con deny, también bloquea cambios no relacionados en una cuenta
# existente que no cumple (gotcha: deny-blocks-changes-on-noncompliant-accounts).
resource "azurerm_policy_definition" "no_public_blob" {
  name                = "${var.name}-no-public-blob"
  policy_type         = "Custom"
  mode                = "All"
  display_name        = "Storage accounts: acceso anónimo a blobs deshabilitado"
  description         = "Evita storage accounts con allowBlobPublicAccess distinto de false."
  management_group_id = var.management_group_id

  metadata = jsonencode({ category = "Storage" })

  parameters = jsonencode({
    effect = {
      type = "String"
      metadata = {
        displayName = "Efecto"
      }
      allowedValues = ["audit", "deny"]
      defaultValue  = "deny"
    }
  })

  policy_rule = jsonencode({
    "if" = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.Storage/storageAccounts"
        },
        {
          not = {
            field  = "Microsoft.Storage/storageAccounts/allowBlobPublicAccess"
            equals = "false"
          }
        },
      ]
    }
    "then" = {
      effect = "[parameters('effect')]"
    }
  })
}

# enforce = false deja la asignación en DoNotEnforce (gotcha: donotenforce-evaluates-without-blocking).
# Con effect = "audit" la request pasa igual (gotcha: audit-does-not-block).
resource "azurerm_management_group_policy_assignment" "no_public_blob" {
  name                 = "${var.name}-nopublic"
  display_name         = "Storage accounts sin acceso anónimo a blobs"
  management_group_id  = var.management_group_id
  policy_definition_id = azurerm_policy_definition.no_public_blob.id
  enforce              = var.enforce
  not_scopes           = var.not_scopes

  parameters = jsonencode({
    effect = { value = var.effect }
  })

  non_compliance_message {
    content = "Esta organización no permite acceso anónimo a blobs: poné allowBlobPublicAccess en false o pedí una excepción."
  }
}

# La excepción vence y queda con quién la pidió y quién la aprobó (gotcha: exemption-expiry-is-optional).
# Al vencer no se borra: deja de honrarse y queda como registro.
resource "azurerm_subscription_policy_exemption" "this" {
  for_each = var.exemptions

  name                 = each.key
  subscription_id      = each.value.subscription_id
  policy_assignment_id = azurerm_management_group_policy_assignment.no_public_blob.id
  exemption_category   = each.value.category
  display_name         = each.value.reason
  expires_on           = each.value.expires_on

  metadata = jsonencode({
    requestedBy = each.value.requested_by
    approvedBy  = each.value.approved_by
    ticketRef   = each.value.ticket
  })
}
