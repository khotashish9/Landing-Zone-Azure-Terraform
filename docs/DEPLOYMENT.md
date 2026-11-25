# Deployment and operations

## 1. Prerequisites

- Terraform >= 1.9, Azure CLI >= 2.60, GitHub repository.
- Three subscriptions (management, connectivity, identity). Optional: a Corp workload subscription.
- Deploying identity needs, at tenant root management group scope: **Owner** (or Management Group
  Contributor + User Access Administrator + Resource Policy Contributor) plus rights in each subscription.
- Providers registered in each subscription: `Microsoft.Network`, `Microsoft.OperationalInsights`,
  `Microsoft.SecurityInsights`, `Microsoft.Security`, `Microsoft.PolicyInsights`, `Microsoft.Insights`.

If you are a Global Administrator without Azure RBAC, elevate once:

```bash
az rest --method post --url "/providers/Microsoft.Authorization/elevateAccess?api-version=2016-07-01"
az role assignment create --assignee <your-object-id> --role Owner --scope /providers/Microsoft.Management/managementGroups/<tenant-id>
```
Then remove the elevation when done.

## 2. Bootstrap state

```bash
SUB=<mgmt-sub> SA=<unique> ./scripts/bootstrap-backend.sh
cp backend.hcl.example backend.hcl
```

## 3. Configure

```bash
cp terraform.tfvars.example terraform.tfvars
az login && ./scripts/validate-policy-ids.sh      # every ID must show OK
```

Make sure every key in `required_tags` also exists in `tags`.

## 4. Deploy (recommended two-pass rollout)

```bash
terraform init -backend-config=backend.hcl
# Pass 1: observe only
terraform apply -var policy_enforcement=false -parallelism=3
# Review compliance (Portal > Policy > Compliance) for 1-2 days, add exemptions / fix workloads
# Pass 2: enforce
terraform apply -var policy_enforcement=true -parallelism=3
```

`-parallelism=3` avoids "another operation in progress" conflicts when enabling Defender plans.
New management groups can take a few minutes to propagate; if an apply fails with a 404 on a management
group or policy definition, re-run it.

## 5. GitHub Actions setup

1. Create an Entra app registration with federated credentials for the repo
   (`repo:<org>/<repo>:ref:refs/heads/main` and `...:environment:production`).
2. Grant it the roles from section 1 at the root MG and Storage Blob Data Contributor on the state account.
3. Repository **Variables**: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_MANAGEMENT_SUBSCRIPTION_ID`,
   `AZURE_CONNECTIVITY_SUBSCRIPTION_ID`, `AZURE_IDENTITY_SUBSCRIPTION_ID`, `SECURITY_CONTACT_EMAIL`,
   `TFSTATE_RG`, `TFSTATE_SA`.
4. Create environments `plan` and `production`; add required reviewers to `production`.
5. Enable branch protection on `main`, require the `validate` job, and add a CODEOWNERS file.

The pipeline uses defaults for non-secret inputs; supply further values via `TF_VAR_*` variables or a
committed `*.auto.tfvars` that contains no secrets (note `*.auto.tfvars` is git-ignored here by default).

## 6. Day-2 operations

| Task | How |
|---|---|
| Onboard a workload subscription | Create it, add `corp_subscription_id` (or move it into the MG via your vending pipeline); policies and Defender apply by inheritance |
| New workload spoke | Copy `modules/spoke_network` usage from `main.tf` with a new `workload_name` and address space |
| Add a policy | See [POLICIES.md](POLICIES.md#adding-a-policy) |
| Temporary exception | Policy exemption with `expires_on`; the alert rule notifies SecOps |
| Remediate existing resources | `az policy remediation create --name fix-x --policy-assignment <id> --management-group <mg>` |
| Upgrade azurerm | Bump the constraint, `terraform init -upgrade`, review the plan |
| Drift detection | Schedule `terraform plan -detailed-exitcode` in CI |

## 7. Destroy

Locks and `prevent_deletion_if_contains_resources` protect platform resources. To tear down a lab:
set `enable_resource_locks = false`, apply, move or delete workload subscriptions from the hierarchy,
then `terraform destroy`. Management groups must be empty to be deleted.

## 8. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `AuthorizationFailed` on management group | Missing root-MG role (section 1) |
| `PolicyDefinitionNotFound` | Run `validate-policy-ids.sh`; GUID not available in your cloud |
| RG creation denied after policy apply | Tags missing a required key; fix `tags` |
| Assignment name too long | Keys in `assignments.tf` and tag names must keep names at most 24 chars |
| `InvalidTemplateDeployment` in DINE remediation | Check the assignment identity roles propagated, then re-run remediation |
| Subscription already associated | A subscription can be in only one MG; remove duplicates in the variables |
