terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

resource "azurerm_security_center_subscription_pricing" "this" {
  for_each = var.plans

  resource_type = each.key
  tier          = "Standard"
  subplan       = each.value.subplan
}

resource "azurerm_security_center_contact" "this" {
  name                = "default1"
  email               = var.security_contact_email
  alert_notifications = true
  alerts_to_admins    = true
}
