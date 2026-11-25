terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
    time = {
      source = "hashicorp/time"
    }
  }
}

# Every *.json file in ./definitions becomes a custom policy definition at the
# root management group. File name = definition name.
locals {
  definition_files = fileset("${path.module}/definitions", "*.json")
  definitions = {
    for f in local.definition_files :
    trimsuffix(f, ".json") => jsondecode(file("${path.module}/definitions/${f}"))
  }
}

resource "azurerm_policy_definition" "custom" {
  for_each = toset(keys(local.definitions))

  name                = each.key
  policy_type         = "Custom"
  mode                = local.definitions[each.key].mode
  display_name        = local.definitions[each.key].displayName
  description         = local.definitions[each.key].description
  management_group_id = var.management_group_ids["root"]

  metadata = jsonencode({
    category = "Landing Zone"
    version  = local.definitions[each.key].version
  })
  parameters  = jsonencode(local.definitions[each.key].parameters)
  policy_rule = jsonencode(local.definitions[each.key].policyRule)
}

# Custom initiative bundling the security guardrails that are not available as
# built-ins. Assigned once at the root management group.
resource "azurerm_policy_set_definition" "guardrails" {
  name                = "lz-custom-guardrails"
  policy_type         = "Custom"
  display_name        = "Landing Zone - custom security guardrails"
  description         = "Deny Internet-exposed management ports and deploy Key Vault diagnostics."
  management_group_id = var.management_group_ids["root"]

  metadata = jsonencode({ category = "Landing Zone", version = "1.0.0" })

  parameters = jsonencode({
    logAnalytics = {
      type     = "String"
      metadata = { displayName = "Log Analytics workspace resource ID" }
    }
  })

  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.custom["lz-deny-nsg-mgmt-ports-internet"].id
    reference_id         = "denyNsgMgmtPorts"
    parameter_values     = jsonencode({ effect = { value = "Deny" } })
  }

  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.custom["lz-deploy-keyvault-diagnostics"].id
    reference_id         = "keyVaultDiagnostics"
    parameter_values = jsonencode({
      effect       = { value = "DeployIfNotExists" }
      logAnalytics = { value = "[parameters('logAnalytics')]" }
    })
  }
}

# Definitions/initiatives need a moment to replicate before they can be assigned.
resource "time_sleep" "propagation" {
  create_duration = "30s"

  depends_on = [
    azurerm_policy_definition.custom,
    azurerm_policy_set_definition.guardrails,
  ]
}
