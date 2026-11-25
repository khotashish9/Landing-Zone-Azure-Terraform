output "ids" {
  description = "Management group IDs keyed: root, platform, landing_zones, sandbox, decommissioned, management, connectivity, identity, corp, online."
  value       = local.ids
}
