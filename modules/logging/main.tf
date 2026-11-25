terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

data "azurerm_subscription" "current" {}

resource "azurerm_resource_group" "mgmt" {
  name     = "rg-${var.prefix}-mgmt-${var.location}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = "log-${var.prefix}-platform-${var.location}"
  location            = azurerm_resource_group.mgmt.location
  resource_group_name = azurerm_resource_group.mgmt.name
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_in_days
  tags                = var.tags
}

resource "azurerm_sentinel_log_analytics_workspace_onboarding" "this" {
  count        = var.enable_sentinel ? 1 : 0
  workspace_id = azurerm_log_analytics_workspace.this.id
}

resource "azurerm_management_lock" "workspace" {
  count      = var.enable_resource_locks ? 1 : 0
  name       = "lock-do-not-delete"
  scope      = azurerm_log_analytics_workspace.this.id
  lock_level = "CanNotDelete"
  notes      = "Central security log store - removal requires change approval."
}

############################
# Alerting on high-risk control-plane operations
############################
resource "azurerm_monitor_action_group" "security" {
  name                = "ag-${var.prefix}-security"
  resource_group_name = azurerm_resource_group.mgmt.name
  short_name          = "secops"
  tags                = var.tags

  email_receiver {
    name                    = "secops"
    email_address           = var.security_contact_email
    use_common_alert_schema = true
  }
}

locals {
  alert_operations = {
    policy-assignment-delete = "Microsoft.Authorization/policyAssignments/delete"
    policy-exemption-write   = "Microsoft.Authorization/policyExemptions/write"
    role-assignment-write    = "Microsoft.Authorization/roleAssignments/write"
    nsg-delete               = "Microsoft.Network/networkSecurityGroups/delete"
    firewall-delete          = "Microsoft.Network/azureFirewalls/delete"
  }
}

resource "azurerm_monitor_activity_log_alert" "ops" {
  for_each = local.alert_operations

  name                = "ala-${var.prefix}-${each.key}"
  resource_group_name = azurerm_resource_group.mgmt.name
  location            = "global"
  scopes              = [data.azurerm_subscription.current.id]
  description         = "Alert on ${each.value}"
  tags                = var.tags

  criteria {
    category       = "Administrative"
    operation_name = each.value
  }

  action {
    action_group_id = azurerm_monitor_action_group.security.id
  }
}
