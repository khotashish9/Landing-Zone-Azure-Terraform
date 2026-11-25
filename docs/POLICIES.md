# Policy catalog

Defined in `modules/policy/assignments.tf`. "Scope" is the management group key.
Effects are enforced when `policy_enforcement = true`; set it to `false` for a DoNotEnforce rollout.

## Custom definitions (`modules/policy/definitions`)

| Definition | Mode | Effect | Purpose |
|---|---|---|---|
| `lz-deny-nsg-mgmt-ports-internet` | All | Deny | Blocks inbound Allow from Internet/any to 22, 3389 or `*` (standalone and inline NSG rules). Port ranges/lists are not evaluated. |
| `lz-deploy-keyvault-diagnostics` | Indexed | DeployIfNotExists | Streams Key Vault audit logs and metrics to the central workspace |
| `lz-deny-all-decommissioned` | All | Deny | Blocks writes to anything outside `Microsoft.Authorization/*` in decommissioned subscriptions |

The first two are bundled in the initiative `lz-custom-guardrails`, assigned at root.

## Assignments

| Assignment | Scope | Effect | Why |
|---|---|---|---|
| `mscb` | root | Audit | Microsoft cloud security benchmark: broad posture baseline (maps to CIS/NIST/ISO) |
| `allowed-locations` | root | Deny | Data residency / sprawl control |
| `allowed-locations-rg` | root | Deny | Same for resource groups |
| `deny-classic-resources` | root | Deny | Classic (ASM) resources are retired |
| `storage-secure-transfer` | root | Deny | HTTPS only |
| `storage-no-public-blob` | root | Deny | No anonymous blob access |
| `storage-min-tls` | root | Deny | TLS 1.2 minimum |
| `kv-soft-delete` | root | Deny | Recoverability of secrets |
| `kv-purge-protection` | root | Deny | Prevent malicious/accidental purge |
| `activity-log-to-law` | root | DINE | Central audit trail |
| `lz-custom-guardrails` | root | Deny + DINE | No public SSH/RDP; Key Vault diagnostics |
| `req-tag-<tag>` (per required tag) | root | Deny | Resource groups must carry the tag |
| `inh-tag-<tag>` (per required tag) | root | Modify | Resources inherit the tag from the RG |
| `sql-no-public-access` | landing_zones | Deny | SQL only via Private Link |
| `subnet-requires-nsg` | landing_zones | AuditIfNotExists | Network segmentation |
| `defender-servers/storage/keyvault/sql` | landing_zones | DINE | Defender plans for workload subscriptions |
| `corp-no-public-ip` | corp | Deny | Corp stays private |
| `sandbox-no-hybrid-net` | sandbox | Deny | No peering/gateways/ExpressRoute from sandbox |
| `decom-deny-resources` | decommissioned | Deny | Nothing new in retired subscriptions |

## Managed identities and roles

| Assignment | Roles granted to its managed identity |
|---|---|
| `activity-log-to-law`, `lz-custom-guardrails` | Monitoring Contributor, Log Analytics Contributor |
| `inh-tag-*` | Tag Contributor |
| `defender-*` | Security Admin |

## Adding a policy

1. Custom: drop `my-policy.json` into `modules/policy/definitions/` (fields: `displayName`, `description`,
   `mode`, `version`, `parameters`, `policyRule`), then add an entry to `base_assignments`.
2. Built-in: add its GUID to `local.builtin`, then an entry to `base_assignments`.
3. Assignment keys become assignment names and must be at most 24 characters.
4. Update this table, run `scripts/validate-policy-ids.sh`, and roll out with enforcement off first.

## Exemptions and remediation

- Exempt with `azurerm_management_group_policy_exemption` / `azurerm_resource_policy_exemption`, with
  an `expires_on` date and a ticket reference in the description. Exemption creation raises a security alert.
- DINE/Modify policies only act on new or changed resources. Remediate existing ones with
  `az policy remediation create` (or `azurerm_management_group_policy_remediation`).
- Assignments evaluate about every 24 hours; force with `az policy state trigger-scan`.

## Known limitations

- NSG policy ignores port ranges and multi-port lists; pair with Defender JIT and Azure Bastion.
- Defender policy GUIDs and parameter names change occasionally; `validate-policy-ids.sh` checks existence.
- `mscb` assigned at root overlaps with the initiative Defender for Cloud creates per subscription;
  compliance shows twice. This is expected.
