output "vnet_id" {
  value = azurerm_virtual_network.hub.id
}

output "vnet_name" {
  value = azurerm_virtual_network.hub.name
}

output "resource_group_name" {
  value = azurerm_resource_group.hub.name
}

output "firewall_private_ip" {
  value = azurerm_firewall.hub.ip_configuration[0].private_ip_address
}

output "private_dns_zone_ids" {
  description = "Private DNS zone IDs keyed by zone name."
  value       = { for k, z in azurerm_private_dns_zone.this : k => z.id }
}
