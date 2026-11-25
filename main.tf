# Required tags must be present in var.tags, otherwise the "require tag on
# resource group" policy would block this very deployment.
check "required_tags_present" {
  assert {
    condition     = alltrue([for t in var.required_tags : contains(keys(var.tags), t)])
    error_message = "Every entry in required_tags must also be a key in var.tags."
  }
}

############################
# 1. Management group hierarchy + subscription placement
############################
module "management_groups" {
  source = "./modules/management_groups"

  prefix                     = var.prefix
  root_display_name          = var.root_display_name
  parent_management_group_id = var.parent_management_group_id

  subscription_associations = merge(
    {
      management = {
        management_group_key = "management"
        subscription_id      = var.management_subscription_id
      }
      connectivity = {
        management_group_key = "connectivity"
        subscription_id      = var.connectivity_subscription_id
      }
      identity = {
        management_group_key = "identity"
        subscription_id      = var.identity_subscription_id
      }
    },
    var.corp_subscription_id == null ? {} : {
      corp = {
        management_group_key = "corp"
        subscription_id      = var.corp_subscription_id
      }
    }
  )
}

############################
# 2. Central logging, Sentinel, security alerting (management subscription)
############################
module "logging" {
  source = "./modules/logging"

  prefix                 = var.prefix
  location               = var.location
  retention_in_days      = var.log_retention_days
  enable_sentinel        = var.enable_sentinel
  enable_resource_locks  = var.enable_resource_locks
  security_contact_email = var.security_contact_email
  tags                   = var.tags

  depends_on = [module.management_groups]
}

############################
# 3. Hub network (connectivity subscription)
############################
module "hub_network" {
  source    = "./modules/hub_network"
  providers = { azurerm = azurerm.connectivity }

  prefix                     = var.prefix
  location                   = var.location
  address_space              = var.hub_address_space
  internal_address_space     = var.internal_address_space
  firewall_sku               = var.firewall_sku
  zones                      = var.availability_zones
  enable_bastion             = var.enable_bastion
  enable_ddos_protection     = var.enable_ddos_protection
  enable_resource_locks      = var.enable_resource_locks
  log_analytics_workspace_id = module.logging.workspace_id
  tags                       = var.tags

  depends_on = [module.management_groups]
}

############################
# 4. Defender for Cloud on the platform subscriptions
#    (landing-zone subscriptions are covered by policy - see modules/policy)
############################
module "defender_management" {
  source                 = "./modules/defender"
  providers              = { azurerm = azurerm }
  plans                  = var.defender_plans
  security_contact_email = var.security_contact_email
}

module "defender_connectivity" {
  source                 = "./modules/defender"
  providers              = { azurerm = azurerm.connectivity }
  plans                  = var.defender_plans
  security_contact_email = var.security_contact_email
}

module "defender_identity" {
  source                 = "./modules/defender"
  providers              = { azurerm = azurerm.identity }
  plans                  = var.defender_plans
  security_contact_email = var.security_contact_email
}

############################
# 5. Azure Policy: custom definitions, initiatives, assignments
#    Depends on logging + hub so their resource groups exist before
#    deny-policies start evaluating.
############################
module "policy" {
  source = "./modules/policy"

  management_group_ids       = module.management_groups.ids
  location                   = var.location
  log_analytics_workspace_id = module.logging.workspace_id
  allowed_locations          = var.allowed_locations
  required_tags              = var.required_tags
  enforce_policies           = var.policy_enforcement

  depends_on = [module.logging, module.hub_network]
}

############################
# 6. Optional sample spoke (Corp landing zone)
############################
module "sample_spoke" {
  count  = var.deploy_sample_spoke && var.corp_subscription_id != null ? 1 : 0
  source = "./modules/spoke_network"
  providers = {
    azurerm     = azurerm.corp
    azurerm.hub = azurerm.connectivity
  }

  prefix                     = var.prefix
  workload_name              = "corp-sample"
  location                   = var.location
  address_space              = var.spoke_address_space
  firewall_private_ip        = module.hub_network.firewall_private_ip
  hub_vnet_id                = module.hub_network.vnet_id
  hub_vnet_name              = module.hub_network.vnet_name
  hub_resource_group_name    = module.hub_network.resource_group_name
  private_dns_zone_ids       = module.hub_network.private_dns_zone_ids
  tags                       = var.tags

  depends_on = [module.policy]
}

############################
# 7. RBAC at management-group scope (use Entra groups, not users)
############################
resource "azurerm_role_assignment" "mg" {
  for_each = var.rbac_assignments

  scope                = module.management_groups.ids[each.value.management_group_key]
  role_definition_name = each.value.role_definition_name
  principal_id         = each.value.principal_id
}
