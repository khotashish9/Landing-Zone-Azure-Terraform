terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

# Caf-style hierarchy:
#
#   <root>
#   ├── platform ── management | connectivity | identity
#   ├── landing_zones ── corp | online
#   ├── sandbox
#   └── decommissioned

locals {
  level1 = {
    platform       = "Platform"
    landing_zones  = "Landing Zones"
    sandbox        = "Sandbox"
    decommissioned = "Decommissioned"
  }
  platform_children = {
    management   = "Management"
    connectivity = "Connectivity"
    identity     = "Identity"
  }
  landing_zone_children = {
    corp   = "Corp"
    online = "Online"
  }
}

resource "azurerm_management_group" "root" {
  name                       = var.prefix
  display_name               = var.root_display_name
  parent_management_group_id = var.parent_management_group_id
}

resource "azurerm_management_group" "level1" {
  for_each = local.level1

  name                       = "${var.prefix}-${replace(each.key, "_", "-")}"
  display_name               = each.value
  parent_management_group_id = azurerm_management_group.root.id
}

resource "azurerm_management_group" "platform" {
  for_each = local.platform_children

  name                       = "${var.prefix}-${each.key}"
  display_name               = each.value
  parent_management_group_id = azurerm_management_group.level1["platform"].id
}

resource "azurerm_management_group" "landing_zones" {
  for_each = local.landing_zone_children

  name                       = "${var.prefix}-${each.key}"
  display_name               = each.value
  parent_management_group_id = azurerm_management_group.level1["landing_zones"].id
}

locals {
  ids = merge(
    { root = azurerm_management_group.root.id },
    { for k, v in azurerm_management_group.level1 : k => v.id },
    { for k, v in azurerm_management_group.platform : k => v.id },
    { for k, v in azurerm_management_group.landing_zones : k => v.id },
  )
}

resource "azurerm_management_group_subscription_association" "this" {
  for_each = var.subscription_associations

  management_group_id = local.ids[each.value.management_group_key]
  subscription_id     = "/subscriptions/${each.value.subscription_id}"
}
