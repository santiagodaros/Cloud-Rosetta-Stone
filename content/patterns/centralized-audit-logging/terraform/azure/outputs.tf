output "workspace_id" {
  description = "Workspace de Log Analytics que recibe el Activity Log (tabla AzureActivity)."
  value       = azurerm_log_analytics_workspace.audit.id
}

output "diagnostic_setting_ids" {
  description = "Diagnostic setting por suscripción de origen."
  value       = { for k, d in azurerm_monitor_diagnostic_setting.activity_log : k => d.id }
}
