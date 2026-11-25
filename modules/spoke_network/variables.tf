variable "prefix" {
  type = string
}

variable "workload_name" {
  type = string
}

variable "location" {
  type = string
}

variable "address_space" {
  type = list(string)
}

variable "firewall_private_ip" {
  type = string
}

variable "hub_vnet_id" {
  type = string
}

variable "hub_vnet_name" {
  type = string
}

variable "hub_resource_group_name" {
  type = string
}

variable "private_dns_zone_ids" {
  description = "Map of private DNS zone name => ID (hub module output)."
  type        = map(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}
