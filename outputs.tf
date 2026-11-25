output "management_group_ids" {
  description = "Management group resource IDs keyed by role."
  value       = module.management_groups.ids
}

output "log_analytics_workspace_id" {
  value = module.logging.workspace_id
}

output "hub_vnet_id" {
  value = module.hub_network.vnet_id
}

output "hub_firewall_private_ip" {
  value = module.hub_network.firewall_private_ip
}

output "policy_assignment_ids" {
  description = "Policy assignment IDs keyed by assignment name."
  value       = module.policy.assignment_ids
}
