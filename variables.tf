############################
# Tenant / subscriptions
############################
variable "tenant_id" {
  description = "Entra ID (Azure AD) tenant ID."
  type        = string
}

variable "management_subscription_id" {
  description = "Subscription for management/logging/monitoring resources."
  type        = string
}

variable "connectivity_subscription_id" {
  description = "Subscription for the hub network (firewall, bastion, private DNS)."
  type        = string
}

variable "identity_subscription_id" {
  description = "Subscription for identity workloads (e.g. domain controllers)."
  type        = string
}

variable "corp_subscription_id" {
  description = "Optional landing-zone subscription placed in the Corp management group (and used for the sample spoke)."
  type        = string
  default     = null
}

############################
# Naming / location / tags
############################
variable "prefix" {
  description = "Short prefix used for management group IDs and resource names (2-10 chars: a-z, 0-9, hyphen)."
  type        = string
  default     = "alz"

  validation {
    condition     = can(regex("^[a-z0-9-]{2,10}$", var.prefix))
    error_message = "prefix must be 2-10 characters: lowercase letters, digits or hyphen."
  }
}

variable "root_display_name" {
  description = "Display name of the top-level (intermediate root) management group."
  type        = string
  default     = "Contoso"
}

variable "parent_management_group_id" {
  description = "Parent of the top-level management group. null = Tenant Root Group."
  type        = string
  default     = null
}

variable "location" {
  description = "Primary Azure region."
  type        = string
  default     = "westeurope"
}

variable "tags" {
  description = "Tags applied to every resource group/resource created here. Must contain every key in required_tags."
  type        = map(string)
  default = {
    CostCenter  = "platform"
    Environment = "prod"
    Owner       = "platform-team@example.com"
    ManagedBy   = "terraform"
  }
}

############################
# Governance
############################
variable "allowed_locations" {
  description = "Regions where resources may be deployed (include 'global' for global resources)."
  type        = list(string)
  default     = ["westeurope", "northeurope", "global"]
}

variable "required_tags" {
  description = "Tag names enforced on resource groups and inherited by resources."
  type        = list(string)
  default     = ["CostCenter", "Environment", "Owner"]

  validation {
    condition     = alltrue([for t in var.required_tags : can(regex("^[A-Za-z0-9]{1,14}$", t))])
    error_message = "Each required tag must be alphanumeric and at most 14 characters (policy assignment names are limited to 24 characters)."
  }
}

variable "policy_enforcement" {
  description = "true = Deny/DINE policies are enforced. false = DoNotEnforce (audit-only rollout)."
  type        = bool
  default     = true
}

variable "rbac_assignments" {
  description = "Role assignments at management-group scope. management_group_key is one of: root, platform, management, connectivity, identity, landing_zones, corp, online, sandbox, decommissioned."
  type = map(object({
    management_group_key = string
    role_definition_name = string
    principal_id         = string
  }))
  default = {}
}

############################
# Security / monitoring
############################
variable "security_contact_email" {
  description = "Email for Defender for Cloud alerts and Azure Monitor security alerts."
  type        = string
}

variable "log_retention_days" {
  description = "Log Analytics retention in days (30-730)."
  type        = number
  default     = 365
}

variable "enable_sentinel" {
  description = "Onboard Microsoft Sentinel on the central workspace."
  type        = bool
  default     = true
}

variable "defender_plans" {
  description = "Defender for Cloud plans to enable on the platform subscriptions."
  type = map(object({
    subplan = optional(string)
  }))
  default = {
    VirtualMachines = { subplan = "P2" }
    StorageAccounts = {}
    KeyVaults       = {}
    Arm             = {}
    AppServices     = {}
    SqlServers      = {}
    Containers      = {}
    CloudPosture    = {}
  }
}

variable "enable_resource_locks" {
  description = "Apply CanNotDelete locks to core platform resources."
  type        = bool
  default     = true
}

############################
# Networking
############################
variable "hub_address_space" {
  description = "Hub VNet address space (at least /22)."
  type        = list(string)
  default     = ["10.0.0.0/22"]
}

variable "internal_address_space" {
  description = "Supernet containing all internal networks (used in firewall rules)."
  type        = string
  default     = "10.0.0.0/8"
}

variable "firewall_sku" {
  description = "Azure Firewall policy SKU: Standard or Premium (Premium adds IDPS/TLS inspection)."
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Premium"], var.firewall_sku)
    error_message = "firewall_sku must be Standard or Premium."
  }
}

variable "availability_zones" {
  description = "Zones for firewall/public IPs. Use [] for regions without zones."
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "enable_bastion" {
  description = "Deploy Azure Bastion in the hub."
  type        = bool
  default     = true
}

variable "enable_ddos_protection" {
  description = "Create and attach a DDoS Protection plan (about USD 2,900/month - off by default)."
  type        = bool
  default     = false
}

variable "deploy_sample_spoke" {
  description = "Deploy a sample peered, firewall-routed spoke VNet into corp_subscription_id."
  type        = bool
  default     = false
}

variable "spoke_address_space" {
  description = "Address space of the sample spoke (a /24 is assumed for subnet carving)."
  type        = list(string)
  default     = ["10.1.0.0/24"]
}
