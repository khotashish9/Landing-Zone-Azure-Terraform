# Security and governance best practices

Legend: **Code** = implemented by this repository, **Policy** = enforced/audited by Azure Policy,
**Manual** = must be configured outside Terraform (tenant-level or licence-dependent).

## Identity and access

| Practice | Status | Notes |
|---|---|---|
| RBAC with Entra groups at MG scope | Code | `rbac_assignments`; never assign to individuals |
| Least-privilege roles for policy identities | Code | Tag Contributor / Monitoring Contributor / Security Admin only |
| Privileged Identity Management (just-in-time Owner/Contributor) | Manual | Make platform owners PIM-eligible, approval + MFA on activation |
| Two emergency (break-glass) cloud-only accounts | Manual | Excluded from Conditional Access, alert on sign-in, credentials in a safe |
| Conditional Access: MFA for all, block legacy auth, MFA for Azure management | Manual | Entra ID P1/P2 |
| Restrict subscription creation/transfer, disable tenant-wide "Owner can change MG" | Manual | Tenant and MG settings |
| Access reviews for privileged groups | Manual | Entra ID Governance |
| Workload identities: managed identities over secrets | Practice | Pipeline uses OIDC federation |

## Governance

| Practice | Status |
|---|---|
| Management-group hierarchy and subscription vending placement | Code |
| Policy as code, version-controlled with PR review | Code + CI |
| Region restriction (data residency) | Policy |
| Mandatory tags with inheritance (cost allocation, ownership) | Policy |
| Deprecated resource types blocked | Policy |
| Audit-only rollout switch and exemptions with expiry | Code (`policy_enforcement`) |
| Resource locks on platform resources | Code (`enable_resource_locks`) |
| Budgets and cost alerts per subscription | Manual (add `azurerm_consumption_budget_subscription` in your vending pipeline) |
| Azure Advisor/Service Health alerts | Manual |

## Network security

| Practice | Status |
|---|---|
| Hub and spoke with central firewall, forced tunnelling via UDR | Code |
| Threat intelligence deny, DNS proxy, IDPS (Premium) | Code |
| No public SSH/RDP; Bastion for admin access | Code + Policy |
| NSG on every subnet, default-deny inbound | Code (spoke) + Policy (audit) |
| No default outbound access on workload subnets | Code (spoke) |
| Private Link + central private DNS zones | Code |
| Corp has no public IPs; SQL/Storage public access denied | Policy |
| DDoS Protection for public-facing workloads | Code (`enable_ddos_protection`) |
| WAF in front of Online workloads (Front Door/App Gateway) | Manual (per workload) |
| VNet flow logs to the workspace | Manual (NSG flow logs are being retired; use VNet flow logs) |

## Data protection

| Practice | Status |
|---|---|
| HTTPS only, TLS 1.2 minimum on storage | Policy |
| No anonymous blob access | Policy |
| Key Vault soft delete + purge protection | Policy |
| Key Vault diagnostic logging | Policy (DINE) |
| Customer-managed keys for regulated data | Manual (per workload) |
| Backup and DR (Recovery Services vault, paired-region plan) | Manual |

## Monitoring and threat detection

| Practice | Status |
|---|---|
| Central Log Analytics with 365-day retention | Code |
| Activity Logs from all subscriptions | Policy (DINE) |
| Sentinel onboarding | Code; connectors Manual |
| Defender for Cloud plans on all subscriptions | Code (platform) + Policy (landing zones) |
| Security contact and alert emails | Code |
| Alerts on policy/RBAC/network control-plane changes | Code |
| Export Defender data to workspace, enable regulatory compliance standards (CIS, ISO 27001, NIST) | Manual |

## Supply chain and pipeline

| Practice | Status |
|---|---|
| OIDC auth, no stored secrets | Code |
| fmt, validate, tflint, Checkov in CI | Code |
| Plan/apply separation, approval on `production` environment | Code (configure reviewers) |
| State: private, versioned, soft-delete, Entra auth, no shared keys | Code (`bootstrap-backend.sh`) |
| Pinned provider versions; commit `.terraform.lock.hcl` | Practice |
| Branch protection, CODEOWNERS, required reviews | Manual (GitHub settings) |

## Compliance mapping (indicative)

The `mscb` initiative provides evidence against CIS Azure Foundations, NIST SP 800-53, ISO 27001 and
PCI DSS through Defender for Cloud's regulatory compliance dashboard. Add additional standards there.
This repository is a baseline, not a certification.
