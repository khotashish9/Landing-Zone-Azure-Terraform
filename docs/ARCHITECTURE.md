# Architecture

## Management group hierarchy

```
Tenant Root Group
└── <prefix>                (intermediate root: tenant-wide policy and RBAC)
    ├── <prefix>-platform
    │   ├── <prefix>-management      Log Analytics, Sentinel, alerts
    │   ├── <prefix>-connectivity    Hub VNet, Firewall, Bastion, Private DNS
    │   └── <prefix>-identity        Identity workloads
    ├── <prefix>-landing-zones
    │   ├── <prefix>-corp            Private, hub-connected workloads
    │   └── <prefix>-online          Internet-facing workloads
    ├── <prefix>-sandbox             Experimentation, isolated from hybrid network
    └── <prefix>-decommissioned      Subscriptions awaiting deletion
```

Why: policy and RBAC inherit downward, so guardrails are written once at the highest sensible scope and
specialised only where needed (Corp: no public IPs, Sandbox: no hybrid networking).
Keep the hierarchy shallow (max 3-4 levels) and organise by *function*, not by org chart.

## Subscriptions

| Subscription | Contents |
|---|---|
| Management | Central Log Analytics workspace, Sentinel, action groups, activity-log alerts |
| Connectivity | Hub VNet, Azure Firewall + policy, Bastion, Private DNS zones, optional DDoS plan |
| Identity | Reserved for identity workloads; Defender baseline applied |
| Landing zone subscriptions | One per workload/environment; placed in Corp or Online (subscription vending) |

The three platform subscriptions must be distinct. A subscription can only belong to one MG.

## Network topology (hub and spoke)

```
                    Internet
                       |
              +--------+--------+
              | Azure Firewall  |  threat intel = Deny, DNS proxy, (Premium: IDPS)
              +--------+--------+
                       |
   +-------------------+-------------------+
   |            Hub VNet (10.0.0.0/22)     |
   |  AzureFirewallSubnet  /26             |
   |  AzureBastionSubnet   /26             |
   |  GatewaySubnet        /27 (reserved)  |
   +-------+---------------------+---------+
           | peering             | peering
   +-------+-------+     +-------+-------+
   | Spoke (Corp)  |     | Spoke (Online)|
   | UDR 0/0 -> FW |     |   ...         |
   | NSG deny-in   |     +---------------+
   +---------------+
```

- All spoke egress is routed to the firewall by user-defined routes; subnets have
  `default_outbound_access_enabled = false`.
- Spokes use the firewall as DNS (proxy) and are linked to central Private DNS zones so Private Link
  names resolve consistently.
- Add VPN/ExpressRoute into `GatewaySubnet` for hybrid connectivity (not deployed by default).
- Platform-wide address plan: hub `10.0.0.0/22`, spokes carved from `10.0.0.0/8`. Adjust before first apply.

## Policy architecture

1. **Custom definitions** (`modules/policy/definitions/*.json`) created at the root MG.
2. **Custom initiative** `lz-custom-guardrails` groups related custom definitions.
3. **Assignments** (`modules/policy/assignments.tf`) bind built-ins, custom definitions and initiatives to
   the lowest scope that makes sense. DeployIfNotExists/Modify assignments get a system-assigned managed
   identity with only the roles the remediation needs.
4. Everything is driven by one uniform map, so adding a policy = adding one map entry.

## Logging and detection

- Subscription Activity Logs flow to the central workspace via the `activity-log-to-law` DINE policy.
- Firewall and Bastion send diagnostics to the same workspace; Key Vault diagnostics are deployed by policy.
- Activity-log alerts notify the security mailbox on policy-assignment deletion, policy-exemption creation,
  role-assignment writes, NSG deletion and firewall deletion.
- Sentinel is onboarded; enable data connectors (Entra ID, Defender for Cloud) after deployment.

## State and identity of the pipeline

Remote state lives in a hardened storage account (shared keys off, versioning, soft delete, GRS, lock).
GitHub Actions authenticates via OIDC federated credentials; no client secrets are stored.
