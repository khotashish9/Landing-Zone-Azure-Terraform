terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

locals {
  fw_subnet      = cidrsubnet(var.address_space[0], 4, 0) # /26
  bastion_subnet = cidrsubnet(var.address_space[0], 4, 1) # /26
  gw_subnet      = cidrsubnet(var.address_space[0], 5, 4) # /27 (reserved for VPN/ExpressRoute)

  # Private Link DNS zones that workloads commonly need. Extend as required.
  private_dns_zones = [
    "privatelink.blob.core.windows.net",
    "privatelink.file.core.windows.net",
    "privatelink.queue.core.windows.net",
    "privatelink.table.core.windows.net",
    "privatelink.vaultcore.azure.net",
    "privatelink.database.windows.net",
    "privatelink.azurewebsites.net",
    "privatelink.azurecr.io",
    "privatelink.servicebus.windows.net",
    "privatelink.documents.azure.com",
    "privatelink.monitor.azure.com",
  ]
}

resource "azurerm_resource_group" "hub" {
  name     = "rg-${var.prefix}-hub-${var.location}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_network_ddos_protection_plan" "this" {
  count               = var.enable_ddos_protection ? 1 : 0
  name                = "ddos-${var.prefix}-hub"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  tags                = var.tags
}

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-${var.prefix}-hub-${var.location}"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  address_space       = var.address_space
  tags                = var.tags

  dynamic "ddos_protection_plan" {
    for_each = var.enable_ddos_protection ? [1] : []
    content {
      id     = azurerm_network_ddos_protection_plan.this[0].id
      enable = true
    }
  }
}

resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [local.fw_subnet]
}

resource "azurerm_subnet" "bastion" {
  count                = var.enable_bastion ? 1 : 0
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [local.bastion_subnet]
}

resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [local.gw_subnet]
}

############################
# Azure Firewall (central egress / east-west inspection)
############################
resource "azurerm_public_ip" "firewall" {
  name                = "pip-${var.prefix}-fw-hub"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.zones
  tags                = var.tags
}

resource "azurerm_firewall_policy" "hub" {
  name                     = "afwp-${var.prefix}-hub"
  location                 = azurerm_resource_group.hub.location
  resource_group_name      = azurerm_resource_group.hub.name
  sku                      = var.firewall_sku
  threat_intelligence_mode = "Deny"
  tags                     = var.tags

  dns {
    proxy_enabled = true
  }

  dynamic "intrusion_detection" {
    for_each = var.firewall_sku == "Premium" ? [1] : []
    content {
      mode = "Deny"
    }
  }
}

# Default-deny: only the rules below are allowed. Add workload-specific
# collection groups (priority > 200) from your workload pipelines.
resource "azurerm_firewall_policy_rule_collection_group" "baseline" {
  name               = "rcg-baseline"
  firewall_policy_id = azurerm_firewall_policy.hub.id
  priority           = 200

  application_rule_collection {
    name     = "allow-platform-services"
    priority = 200
    action   = "Allow"

    rule {
      name = "windows-update"
      protocols {
        type = "Https"
        port = 443
      }
      protocols {
        type = "Http"
        port = 80
      }
      source_addresses      = [var.internal_address_space]
      destination_fqdn_tags = ["WindowsUpdate"]
    }
  }
}

resource "azurerm_firewall" "hub" {
  name                = "afw-${var.prefix}-hub-${var.location}"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  sku_name            = "AZFW_VNet"
  sku_tier            = var.firewall_sku
  firewall_policy_id  = azurerm_firewall_policy.hub.id
  zones               = var.zones
  tags                = var.tags

  ip_configuration {
    name                 = "ipconfig"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }

  depends_on = [azurerm_firewall_policy_rule_collection_group.baseline]
}

resource "azurerm_monitor_diagnostic_setting" "firewall" {
  name                           = "diag-to-law"
  target_resource_id             = azurerm_firewall.hub.id
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category_group = "allLogs"
  }
}

############################
# Azure Bastion (no public RDP/SSH anywhere)
############################
resource "azurerm_public_ip" "bastion" {
  count               = var.enable_bastion ? 1 : 0
  name                = "pip-${var.prefix}-bastion-hub"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.zones
  tags                = var.tags
}

resource "azurerm_bastion_host" "hub" {
  count               = var.enable_bastion ? 1 : 0
  name                = "bas-${var.prefix}-hub-${var.location}"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  sku                 = "Standard"
  tags                = var.tags

  ip_configuration {
    name                 = "ipconfig"
    subnet_id            = azurerm_subnet.bastion[0].id
    public_ip_address_id = azurerm_public_ip.bastion[0].id
  }
}

resource "azurerm_monitor_diagnostic_setting" "bastion" {
  count                      = var.enable_bastion ? 1 : 0
  name                       = "diag-to-law"
  target_resource_id         = azurerm_bastion_host.hub[0].id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "BastionAuditLogs"
  }
}

############################
# Central Private DNS zones for Private Link
############################
resource "azurerm_private_dns_zone" "this" {
  for_each            = toset(local.private_dns_zones)
  name                = each.value
  resource_group_name = azurerm_resource_group.hub.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "hub" {
  for_each              = azurerm_private_dns_zone.this
  name                  = "link-hub"
  resource_group_name   = azurerm_resource_group.hub.name
  private_dns_zone_name = each.value.name
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_management_lock" "hub_rg" {
  count      = var.enable_resource_locks ? 1 : 0
  name       = "lock-do-not-delete"
  scope      = azurerm_resource_group.hub.id
  lock_level = "CanNotDelete"
  notes      = "Core connectivity - removal requires change approval."
}
