variable "management_group_ids" {
  description = "Map from modules/management_groups output (root, platform, landing_zones, corp, online, sandbox, decommissioned, ...)."
  type        = map(string)
}

variable "location" {
  description = "Region for policy managed identities (DeployIfNotExists/Modify)."
  type        = string
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "allowed_locations" {
  type = list(string)
}

variable "required_tags" {
  type = list(string)
}

variable "enforce_policies" {
  description = "false = every assignment is created with enforcement mode DoNotEnforce (audit-only)."
  type        = bool
  default     = true
}
