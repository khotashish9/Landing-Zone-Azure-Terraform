# One provider alias per platform subscription. Azure Landing Zone design keeps
# management, connectivity and identity resources in separate subscriptions.


provider "azurerm" {
  # Default provider = Management subscription
  subscription_id     = var.management_subscription_id
  tenant_id           = var.tenant_id
  storage_use_azuread = true

  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
    key_vault {
      purge_soft_delete_on_destroy = false
    }
  }
}

provider "azurerm" {
  alias               = "connectivity"
  subscription_id     = var.connectivity_subscription_id
  tenant_id           = var.tenant_id
  storage_use_azuread = true

  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}

provider "azurerm" {
  alias               = "identity"
  subscription_id     = var.identity_subscription_id
  tenant_id           = var.tenant_id
  storage_use_azuread = true

  features {}
}

# Sample landing-zone (corp) subscription. Falls back to the management
# subscription ID only so the provider block is valid when no corp subscription
# is supplied; nothing is deployed to it unless deploy_sample_spoke = true.
provider "azurerm" {
  alias               = "corp"
  subscription_id     = coalesce(var.corp_subscription_id, var.management_subscription_id)
  tenant_id           = var.tenant_id
  storage_use_azuread = true

  features {}
}
