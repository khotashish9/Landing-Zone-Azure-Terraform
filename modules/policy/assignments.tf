# Built-in definition IDs. Validate against your tenant with
# scripts/validate-policy-ids.sh before the first apply.
locals {
  pd = "/providers/Microsoft.Authorization/policyDefinitions"
  ps = "/providers/Microsoft.Authorization/policySetDefinitions"

  builtin = {
    mscb                  = "${local.ps}/1f3afdf9-d0c9-4c3d-847f-89da613e70a8" # Microsoft cloud security benchmark
    allowed_locations     = "${local.pd}/e56962a6-4747-49cd-b67b-bf8b01975c4c"
    allowed_locations_rg  = "${local.pd}/e765b5de-1225-4ba3-bd56-1ac6695af988"
    not_allowed_types     = "${local.pd}/6c112d4e-5bc7-47ae-a041-ea2d9dccd749"
    require_rg_tag        = "${local.pd}/96670d01-0a4d-4649-9c89-2d3abc0a5025"
    inherit_rg_tag        = "${local.pd}/ea3f2387-9b95-492a-a190-fcdc54f7b070"
    storage_https         = "${local.pd}/404c3081-a854-4457-ae30-26a93ef643f9"
    storage_no_public     = "${local.pd}/4fa4b6c0-31ca-4c0d-b10d-24b96f62a751"
    storage_min_tls       = "${local.pd}/fe83a0eb-a853-422d-aac2-1bffd182c5d0"
    kv_soft_delete        = "${local.pd}/1e66c121-a66a-4b1f-9b83-0fd99bf0fc2d"
    kv_purge_protection   = "${local.pd}/0b60c0b2-2dc2-4e1c-b5c9-abbed971de53"
    activity_log_to_law   = "${local.pd}/2465583e-4e78-4c15-b6be-a36cbc7c8b0f"
    sql_no_public         = "${local.pd}/1b8ca024-1d5c-4dec-8995-b1a932b41780"
    subnet_requires_nsg   = "${local.pd}/e71308d3-144b-4262-b144-efdc3cc90517"
    defender_servers      = "${local.pd}/8e86a5b6-b9bd-49d1-8e21-4bb8a0862222"
    defender_storage      = "${local.pd}/cfdc5972-75b3-4418-8ae1-7f5c36839390"
    defender_keyvault     = "${local.pd}/1f725891-01c0-420a-9059-4fa46cb770b7"
    defender_sql          = "${local.pd}/b99b73e7-074b-4089-9395-b7236f094491"
  }

  # Every entry has the same attributes (all strings/bool) so the map is uniform.
  #   scope  : key of var.management_group_ids
  #   roles  : comma-separated built-in role names granted to the assignment's
  #            managed identity (needed for DeployIfNotExists / Modify). "" = none.
  base_assignments = {
    "mscb" = {
      scope         = "root"
      definition_id = local.builtin.mscb
      display_name  = "Microsoft cloud security benchmark"
      description   = "Audits resources against the Microsoft cloud security benchmark (maps to CIS/NIST/ISO controls)."
      parameters    = "{}"
      roles         = ""
    }
    "allowed-locations" = {
      scope         = "root"
      definition_id = local.builtin.allowed_locations
      display_name  = "Allowed locations"
      description   = "Restricts resource deployment to approved regions (data residency)."
      parameters    = jsonencode({ listOfAllowedLocations = { value = var.allowed_locations } })
      roles         = ""
    }
    "allowed-locations-rg" = {
      scope         = "root"
      definition_id = local.builtin.allowed_locations_rg
      display_name  = "Allowed locations for resource groups"
      description   = "Restricts resource group creation to approved regions."
      parameters    = jsonencode({ listOfAllowedLocations = { value = var.allowed_locations } })
      roles         = ""
    }
    "deny-classic-resources" = {
      scope         = "root"
      definition_id = local.builtin.not_allowed_types
      display_name  = "Deny classic (ASM) resources"
      description   = "Blocks deprecated classic compute, storage and network resources."
      parameters = jsonencode({
        listOfResourceTypesNotAllowed = { value = [
          "Microsoft.ClassicCompute/virtualMachines",
          "Microsoft.ClassicCompute/domainNames",
          "Microsoft.ClassicStorage/storageAccounts",
          "Microsoft.ClassicNetwork/virtualNetworks",
          "Microsoft.ClassicNetwork/networkSecurityGroups",
        ] }
      })
      roles = ""
    }
    "storage-secure-transfer" = {
      scope         = "root"
      definition_id = local.builtin.storage_https
      display_name  = "Storage: require secure transfer (HTTPS)"
      description   = "Denies storage accounts that allow HTTP."
      parameters    = jsonencode({ effect = { value = "Deny" } })
      roles         = ""
    }
    "storage-no-public-blob" = {
      scope         = "root"
      definition_id = local.builtin.storage_no_public
      display_name  = "Storage: disallow anonymous blob access"
      description   = "Denies storage accounts that allow public blob/container access."
      parameters    = jsonencode({ effect = { value = "Deny" } })
      roles         = ""
    }
    "storage-min-tls" = {
      scope         = "root"
      definition_id = local.builtin.storage_min_tls
      display_name  = "Storage: minimum TLS 1.2"
      description   = "Denies storage accounts with a minimum TLS version below 1.2."
      parameters = jsonencode({
        minimumTlsVersion = { value = "TLS1_2" }
        effect            = { value = "Deny" }
      })
      roles = ""
    }
    "kv-soft-delete" = {
      scope         = "root"
      definition_id = local.builtin.kv_soft_delete
      display_name  = "Key Vault: soft delete enabled"
      description   = "Denies key vaults without soft delete."
      parameters    = jsonencode({ effect = { value = "Deny" } })
      roles         = ""
    }
    "kv-purge-protection" = {
      scope         = "root"
      definition_id = local.builtin.kv_purge_protection
      display_name  = "Key Vault: purge protection enabled"
      description   = "Denies key vaults without purge protection."
      parameters    = jsonencode({ effect = { value = "Deny" } })
      roles         = ""
    }
    "activity-log-to-law" = {
      scope         = "root"
      definition_id = local.builtin.activity_log_to_law
      display_name  = "Stream subscription Activity Log to Log Analytics"
      description   = "DeployIfNotExists: sends every subscription's Activity Log to the central workspace."
      parameters = jsonencode({
        logAnalytics = { value = var.log_analytics_workspace_id }
        effect       = { value = "DeployIfNotExists" }
      })
      roles = "Monitoring Contributor,Log Analytics Contributor"
    }
    "lz-custom-guardrails" = {
      scope         = "root"
      definition_id = azurerm_policy_set_definition.guardrails.id
      display_name  = "Landing Zone custom security guardrails"
      description   = "Custom initiative: deny Internet-exposed SSH/RDP, deploy Key Vault diagnostics."
      parameters    = jsonencode({ logAnalytics = { value = var.log_analytics_workspace_id } })
      roles         = "Monitoring Contributor,Log Analytics Contributor"
    }

    # ---- Landing zones (Corp + Online) ----
    "sql-no-public-access" = {
      scope         = "landing_zones"
      definition_id = local.builtin.sql_no_public
      display_name  = "SQL Database: disable public network access"
      description   = "Denies Azure SQL logical servers with public network access."
      parameters    = jsonencode({ effect = { value = "Deny" } })
      roles         = ""
    }
    "subnet-requires-nsg" = {
      scope         = "landing_zones"
      definition_id = local.builtin.subnet_requires_nsg
      display_name  = "Subnets should have an NSG"
      description   = "Audits subnets that are not protected by a network security group."
      parameters    = jsonencode({ effect = { value = "AuditIfNotExists" } })
      roles         = ""
    }
    "defender-servers" = {
      scope         = "landing_zones"
      definition_id = local.builtin.defender_servers
      display_name  = "Enable Defender for Servers"
      description   = "DeployIfNotExists: enables Defender for Servers on landing-zone subscriptions."
      parameters    = jsonencode({ effect = { value = "DeployIfNotExists" } })
      roles         = "Security Admin"
    }
    "defender-storage" = {
      scope         = "landing_zones"
      definition_id = local.builtin.defender_storage
      display_name  = "Enable Defender for Storage"
      description   = "DeployIfNotExists: enables Defender for Storage on landing-zone subscriptions."
      parameters    = jsonencode({ effect = { value = "DeployIfNotExists" } })
      roles         = "Security Admin"
    }
    "defender-keyvault" = {
      scope         = "landing_zones"
      definition_id = local.builtin.defender_keyvault
      display_name  = "Enable Defender for Key Vault"
      description   = "DeployIfNotExists: enables Defender for Key Vault on landing-zone subscriptions."
      parameters    = jsonencode({ effect = { value = "DeployIfNotExists" } })
      roles         = "Security Admin"
    }
    "defender-sql" = {
      scope         = "landing_zones"
      definition_id = local.builtin.defender_sql
      display_name  = "Enable Defender for SQL"
      description   = "DeployIfNotExists: enables Defender for Azure SQL on landing-zone subscriptions."
      parameters    = jsonencode({ effect = { value = "DeployIfNotExists" } })
      roles         = "Security Admin"
    }

    # ---- Corp: private only ----
    "corp-no-public-ip" = {
      scope         = "corp"
      definition_id = local.builtin.not_allowed_types
      display_name  = "Corp: deny public IP addresses"
      description   = "Corp workloads are private; Internet ingress must go through Online or the hub."
      parameters    = jsonencode({ listOfResourceTypesNotAllowed = { value = ["Microsoft.Network/publicIPAddresses"] } })
      roles         = ""
    }

    # ---- Sandbox: isolated from hybrid connectivity ----
    "sandbox-no-hybrid-net" = {
      scope         = "sandbox"
      definition_id = local.builtin.not_allowed_types
      display_name  = "Sandbox: deny hybrid connectivity"
      description   = "Sandbox must not peer to, or connect with, corporate networks."
      parameters = jsonencode({
        listOfResourceTypesNotAllowed = { value = [
          "Microsoft.Network/virtualNetworkPeerings",
          "Microsoft.Network/virtualNetworkGateways",
          "Microsoft.Network/expressRouteCircuits",
          "Microsoft.Network/vpnGateways",
          "Microsoft.Network/connections",
        ] }
      })
      roles = ""
    }

    # ---- Decommissioned: no new resources ----
    "decom-deny-resources" = {
      scope         = "decommissioned"
      definition_id = azurerm_policy_definition.custom["lz-deny-all-decommissioned"].id
      display_name  = "Decommissioned: deny all resource writes"
      description   = "Subscriptions awaiting deletion may not get new or modified resources."
      parameters    = "{}"
      roles         = ""
    }
  }

  # Tag governance: one "require on RG" + one "inherit from RG" assignment per tag.
  tag_assignments = merge([
    for t in var.required_tags : {
      "req-tag-${lower(t)}" = {
        scope         = "root"
        definition_id = local.builtin.require_rg_tag
        display_name  = "Require tag '${t}' on resource groups"
        description   = "Denies resource groups without the '${t}' tag."
        parameters    = jsonencode({ tagName = { value = t } })
        roles         = ""
      }
      "inh-tag-${lower(t)}" = {
        scope         = "root"
        definition_id = local.builtin.inherit_rg_tag
        display_name  = "Inherit tag '${t}' from resource group"
        description   = "Modify: copies '${t}' from the resource group when a resource lacks it."
        parameters    = jsonencode({ tagName = { value = t } })
        roles         = "Tag Contributor"
      }
    }
  ]...)

  assignments = merge(local.base_assignments, local.tag_assignments)

  role_assignments = merge([
    for k, a in local.assignments : {
      for r in compact(split(",", a.roles)) :
      "${k}|${r}" => { assignment = k, role = r, scope = a.scope }
    }
  ]...)
}

resource "azurerm_management_group_policy_assignment" "this" {
  for_each = local.assignments

  name                 = substr(each.key, 0, 24)
  management_group_id  = var.management_group_ids[each.value.scope]
  policy_definition_id = each.value.definition_id
  display_name         = each.value.display_name
  description          = each.value.description
  enforce              = var.enforce_policies
  parameters           = each.value.parameters == "{}" ? null : each.value.parameters
  location             = each.value.roles != "" ? var.location : null

  dynamic "identity" {
    for_each = each.value.roles != "" ? [1] : []
    content {
      type = "SystemAssigned"
    }
  }

  non_compliance_message {
    content = "Blocked or flagged by landing zone policy: ${each.value.display_name}. See docs/POLICIES.md or request an exemption."
  }

  depends_on = [time_sleep.propagation]
}

# Least-privilege roles for DeployIfNotExists / Modify managed identities.
resource "azurerm_role_assignment" "policy_identity" {
  for_each = local.role_assignments

  scope                            = var.management_group_ids[each.value.scope]
  role_definition_name             = each.value.role
  principal_id                     = azurerm_management_group_policy_assignment.this[each.value.assignment].identity[0].principal_id
  skip_service_principal_aad_check = true
}
