terraform {
  required_providers {
    azurerm = {
      source                = "hashicorp/azurerm"
      configuration_aliases = [azurerm.hub]
    }
  }
}

locals {
  subnets = {
    app               = cidrsubnet(var.address_space[0], 2, 0)
    data              = cidrsubnet(var.address_space[0], 2, 1)
    private-endpoints = cidrsubnet(var.address_space[0], 2, 2)
  }
}

resource "azurerm_resource_group" "spoke" {
  name     = "rg-${var.prefix}-${var.workload_name}-${var.location}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "spoke" {
  name                = "vnet-${var.prefix}-${var.workload_name}-${var.location}"
  location            = azurerm_resource_group.spoke.location
  resource_group_name = azurerm_resource_group.spoke.name
  address_space       = var.address_space
  dns_servers         = [var.firewall_private_ip] # firewall DNS proxy
  tags                = var.tags
}

resource "azurerm_subnet" "this" {
  for_each = local.subnets

  name                            = "snet-${each.key}"
  resource_group_name             = azurerm_resource_group.spoke.name
  virtual_network_name            = azurerm_virtual_network.spoke.name
  address_prefixes                = [each.value]
  default_outbound_access_enabled = false # no implicit Internet egress

  private_endpoint_network_policies = each.key == "private-endpoints" ? "Enabled" : "Disabled"
}

resource "azurerm_network_security_group" "this" {
  for_each = local.subnets

  name                = "nsg-${var.prefix}-${var.workload_name}-${each.key}"
  location            = azurerm_resource_group.spoke.location
  resource_group_name = azurerm_resource_group.spoke.name
  tags                = var.tags

  security_rule {
    name                       = "deny-all-inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each                  = local.subnets
  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = azurerm_network_security_group.this[each.key].id
}

# Force all egress through the hub firewall.
resource "azurerm_route_table" "this" {
  name                          = "rt-${var.prefix}-${var.workload_name}"
  location                      = azurerm_resource_group.spoke.location
  resource_group_name           = azurerm_resource_group.spoke.name
  bgp_route_propagation_enabled = false
  tags                          = var.tags

  route {
    name                   = "default-to-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = var.firewall_private_ip
  }
}

resource "azurerm_subnet_route_table_association" "this" {
  for_each       = { for k, v in local.subnets : k => v if k != "private-endpoints" }
  subnet_id      = azurerm_subnet.this[each.key].id
  route_table_id = azurerm_route_table.this.id
}

############################
# Hub <-> spoke peering (both directions)
############################
resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                         = "peer-to-hub"
  resource_group_name          = azurerm_resource_group.spoke.name
  virtual_network_name         = azurerm_virtual_network.spoke.name
  remote_virtual_network_id    = var.hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  provider                     = azurerm.hub
  name                         = "peer-to-${var.workload_name}"
  resource_group_name          = var.hub_resource_group_name
  virtual_network_name         = var.hub_vnet_name
  remote_virtual_network_id    = azurerm_virtual_network.spoke.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
}

# Resolve Private Link names from the spoke. Zone links are created in the
# connectivity subscription (zones live there).
resource "azurerm_private_dns_zone_virtual_network_link" "spoke" {
  provider = azurerm.hub
  for_each = var.private_dns_zone_ids

  name                  = "link-${var.workload_name}"
  resource_group_name   = var.hub_resource_group_name
  private_dns_zone_name = each.key
  virtual_network_id    = azurerm_virtual_network.spoke.id
  registration_enabled  = false
  tags                  = var.tags
}
