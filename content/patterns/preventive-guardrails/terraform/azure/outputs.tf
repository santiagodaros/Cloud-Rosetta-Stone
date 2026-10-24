output "policy_definition_id" {
  description = "ID de la policy definition."
  value       = azurerm_policy_definition.no_public_blob.id
}

output "policy_assignment_id" {
  description = "ID de la asignación en el management group."
  value       = azurerm_management_group_policy_assignment.no_public_blob.id
}

output "exemption_ids" {
  description = "IDs de las exemptions, por nombre."
  value       = { for k, v in azurerm_subscription_policy_exemption.this : k => v.id }
}
