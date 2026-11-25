output "workspace_id" {
  value = azurerm_log_analytics_workspace.this.id
}

output "resource_group_name" {
  value = azurerm_resource_group.mgmt.name
}

output "action_group_id" {
  value = azurerm_monitor_action_group.security.id
}
