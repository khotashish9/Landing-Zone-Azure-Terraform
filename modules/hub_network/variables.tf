variable "prefix" {
  type = string
}

variable "location" {
  type = string
}

variable "address_space" {
  type = list(string)
}

variable "internal_address_space" {
  type = string
}

variable "firewall_sku" {
  type    = string
  default = "Standard"
}

variable "zones" {
  type    = list(string)
  default = ["1", "2", "3"]
}

variable "enable_bastion" {
  type    = bool
  default = true
}

variable "enable_ddos_protection" {
  type    = bool
  default = false
}

variable "enable_resource_locks" {
  type    = bool
  default = true
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
