variable "prefix" {
  type = string
}

variable "root_display_name" {
  type = string
}

variable "parent_management_group_id" {
  type    = string
  default = null
}

variable "subscription_associations" {
  description = "Subscriptions to place into management groups (one subscription per entry, unique subscriptions only)."
  type = map(object({
    management_group_key = string
    subscription_id      = string
  }))
  default = {}
}
