output "assignment_ids" {
  value = { for k, a in azurerm_management_group_policy_assignment.this : k => a.id }
}

output "custom_definition_ids" {
  value = { for k, d in azurerm_policy_definition.custom : k => d.id }
}
