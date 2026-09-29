# Tagging — Organization Tag Policy (preventive control)

Terraform for the Dyn six-key tagging standard (plus the optional `aiworkload`
key) as an **AWS Organizations tag policy**, managed from the **management
account** (`660571558619`).

> **Status: OBSERVE-ONLY, migrating to lowercase keys.** Policy
> `Organization-Wide-Tagging` (`p-957g5s40o6`) is attached to 16 targets.
> All tag keys are now **lowercase** (`owner`, `environment`, `project`,
> `costcenter`, `stage`, `team`, `aiworkload`); values were already lowercase.
> Enforcement is off (`enforced_resource_types = []`) until resources are
> retagged. The decision is to then enforce all 53 services at once. State is in S3; CI
> plans/applies via the **Deploy Tag Policy** workflow. Full governance doc:
> `Dynmedia/security-account` → `docs/aws-tagging-governance.md`.

This is the **preventive** complement to the **detective** AWS Config rules that
live in the `security-account` repo:

| | AWS Config rules (security-account) | Tag policy (this folder) |
|---|---|---|
| Acts | after a resource exists | at tagging time |
| Can it block? | No — reports only | **Yes** — blocks non-compliant tag *values* on enforced resource types |
| Checks presence (key missing)? | Yes | **No** — untagged resources are not evaluated |
| Checks value (wrong value)? | Yes | Yes |
| Scope control | exclusion list of account IDs | **attachment topology** (see below) |

The two use the **same six keys and allowed values**, so they agree. The one
exception is the optional `aiworkload` key, which exists only in this tag
policy. The Config rule doesn't check it.

---

## What this does and does NOT do

- **Does:** block a tagging operation that sets a value outside the allowed list,
  for the resource types in `enforced_resource_types`, on the value-constrained
  keys (`environment`, `project`, `costcenter`, `stage`, `team`, and the
  optional `aiworkload`).
- **Does NOT:** stop untagged resources. AWS does not evaluate untagged resources
  (or keys not in the policy) against a tag policy. Blocking *creation of
  untagged resources* requires a Service Control Policy — deliberately out of
  scope here.
- **`owner`** is presence-only (no value set), so it is declared but never
  value-enforced.

---

## The keys

Keys are **case-sensitive** in a tag policy: `Environment=production` is
non-compliant, `environment=production` is compliant. Use lowercase keys only.

| Key | Allowed values | Enforced? |
|---|---|---|
| `owner` | any (presence only) | never (no value set) |
| `environment` | production, development, integration, staging, sandbox, shared, security, tools, management, sit | when a resource type is in `enforced_resource_types` |
| `project` | networking, connectivity, shared-services, security-hub, audit, log-archive, infra-tools, api-toolkit, fast, business-intelligence, contentdesk, mimir-fileflows, blog, account-factory | same |
| `costcenter` | product-and-tech, editorial-team | same |
| `stage` | prod, dev, int, staging | same |
| `team` | dcc, infra | same |
| `aiworkload` *(optional)* | developer, product, platform | same, only when present |

`aiworkload` is **not** part of the six-key "tag everything" standard. It
classifies AI resources only (SageMaker, Bedrock agents/knowledge
bases/provisioned throughput, model-hosting compute) for AI cost attribution.
Like every key here, its value is checked when present and its presence is
never required. It is defined in `tag_value_sets` in `tag-policy.tf`
(PR #16).

---

## Scope model — attachment topology, not an exclusion list

Tag policies **attach-and-inherit**. They have **no exclusion field**. You
control coverage purely by *where* you attach. To exclude an account you simply
never attach to it (or to any OU above it).

**Never attach to the organization root** — it would inherit to every account
including the six deliberately-excluded ones and the management account, with no
way to except them. `variables.tf` refuses a root target in validation.

### The six accounts excluded from tagging governance
(the same six excluded from the Config rules)

| ID | Account | OU |
|---|---|---|
| 150384267019 | dyn-contentdesk-prod | Contentdesk |
| 536323235659 | dyn-contentdesk-dev | Contentdesk |
| 911785171405 | dyn-contentdesk-stg | Contentdesk |
| 309066805775 | dyn-deltatreaxis-prod | DeltatreAxis |
| 452957287425 | voscustomer1002.vos | DeltatreAxis |
| 688626526304 | dyn-mmo | (root-level, no OU) |

### How each OU is treated

**Bucket A — attach to the whole OU** (no excluded accounts inside):
Tooling, DynCustomerControl, Workloads, Security, Infrastructure, Tools,
DynBlog, Sandbox-Managed, FX-Digital, Sandbox, AFT, Business-Intelligence, Braze.

**Bucket B — split OUs, attach per-ACCOUNT to the monitored ones only:**
- `Contentdesk` — attach to `386372465922` (mimir-fileflows-prod) and
  `241533154876` (mimir-fileflows-staging); never to the OU (3 excluded live there).
- `DeltatreAxis` — attach to nothing (both accounts excluded).

**Bucket C — never attach:** root, `dyn-mmo`, `aws_mmo`, management account,
`Suspended` OU, empty `Amagi` OU.

> Inheritance caveat (opposite of the Config-rule behaviour): a new account added
> to a Bucket-A OU is auto-governed; a new account in Contentdesk/DeltatreAxis is
> NOT, until you attach it. Note this in operations.

---

## Scope of the current defaults (ORG-WIDE, OBSERVE-ONLY)

> The defaults attach the policy **organization-wide** (every account minus the
> six exclusions) with **no enforcement**. When enforcement is turned on it
> covers **every AWS service that supports tag-policy enforcement** (all 53
> `<service>:ALL_SUPPORTED` tokens, kept as a comment in `variables.tf`).

State once enforcement is turned on:

- **Attachments (16):** 13 whole OUs + the 2 Contentdesk mimir accounts + aws_mmo.
- **Enforcement:** the six value keys (environment, project, costcenter, stage,
  team, aiworkload) carry `enforced_for` across all 53 services. owner stays
  presence-only.

### What enforcement blocks

Across every monitored account, a create/tag operation that sets a
**non-conforming value** (e.g. `environment=dev`, `project=matchday-support`)
on any enforced resource type is **REJECTED at the API** with
`TagPolicyError: The tag policy does not allow the specified value for the
following tag key: '<Key>'.` It does NOT block untagged resources. "All AWS
resources" is not achievable; AWS only supports enforcement for the fixed
service list in `variables.tf`.

Verified on 2026-09-28 in `199964506618` (sandbox-shahriar) with a throwaway S3
bucket: `Environment=dev` and `Team=marketing` rejected; `Environment=development`
and any `Owner` accepted (tested with the old capitalized keys).

### How it was rolled out

1. The hand-made policy was imported into state (see below).
2. First apply with `enforced_resource_types = []`: attached to all 16 targets,
   blocking nothing (2026-09-28 01:29 CEST).
3. Second apply with the full service list: enforcement on
   (2026-09-28 01:46 CEST).
4. `AIWorkload` added via CI (2026-09-28 09:16 CEST).
5. Enforcement rolled back after it blocked a team: `enforced_for` removed from
   the live policy with `aws organizations update-policy` (break-glass, state
   not reachable), then the code default set to `[]` to match. Pre-rollback
   policy JSON was backed up locally.
6. Enforcement for all 53 services merged (PR #20), not applied.
7. Keys switched to lowercase and enforcement default set back to `[]`, before
   any apply of #20. Reason: the org mostly uses lowercase keys already
   (e.g. `environment` on ~6,000 resources vs `Environment` on ~290).

### Re-enabling enforcement

**Decision: enforcement is re-enabled for all 53 services at once**, not in
stages. Set the `enforced_resource_types` default to the full token list (kept
as a comment in `variables.tf`), so `enforced_for` is added to all six value
keys (environment, project, costcenter, stage, team, aiworkload).

Before merging that change:
1. Teams retag to the lowercase keys and allowed values. The 2026-09-28 block
   was DCC's CDK tags (`environment=<domain>`, `project=dcc-backend`).
2. Clean up the remaining mismatches (org-wide tag policy compliance report,
   management account, us-east-1), or
   accept that those teams' next tag-setting deploy will fail.
3. Announce a fixed enforcement date to account owners.

Then run the workflow with `plan` (expect `enforced_for` added to the six value
keys, no attachment changes), then `apply`. If a team is blocked, roll back by
setting the default to `[]` and running `apply` (see Rollback).

### Narrowing later if needed

To reduce scope, edit `attach_target_ids` (remove OUs/accounts) or
`enforced_resource_types` (drop services, or set to `[]`). Only service tokens
that expose `ALL_SUPPORTED` with enforcement support are valid.

---

## Deploy

### Via CI (preferred)
The management account has a GitHub Actions OIDC role,
`GitHubActions-TaggingPolicy-Role`, trusting this repo on `main`. The workflow in
`.github/workflows/` uses it — no long-lived keys, no laptop admin creds. Merge
to `main`, then run the **Deploy Tag Policy** workflow.

### Local (for a plan / break-glass)
```bash
cd Tagging
cp terraform.tfvars.example terraform.tfvars   # adjust if needed
AWS_PROFILE=mgt terraform init
AWS_PROFILE=mgt terraform plan
```

### Import of the existing policy (done)
`Organization-Wide-Tagging` (`p-957g5s40o6`) was originally created by hand.
AWS Organizations rejects duplicate policy names, so it was imported into state
once, locally with the `mgt` profile, before the first apply:
```bash
AWS_PROFILE=mgt terraform import aws_organizations_policy.tagging p-957g5s40o6
```
This is already done and the state is in S3. Only repeat it if the state is
ever lost. The 16 attachments would then need importing too
(`aws_organizations_policy_attachment.tagging["<target-id>"]`, id
`<target-id>:p-957g5s40o6`). `policy_name` defaults to
`Organization-Wide-Tagging` to match the existing policy.

---

## Rollback

Everything is reversible and destroys no member-account resources:
- **Stop blocking:** set `enforced_resource_types = []` and apply — reverts to
  attached-but-detect-only.
- **Remove from a target:** drop it from `attach_target_ids` and apply — that
  OU/account stops being governed immediately (needs `organizations:DetachPolicy`
  — see CI limitation below; do detach locally with the `mgt` profile).
- **Full removal:** `terraform destroy` removes the policy and attachments; no
  member-account resources are affected (also local-only — see below).

## State & CI limitations (read before relying on CI)

- **State is remote (S3).** `s3://dynmedia-terraform-state-660571558619/tagging-policy/terraform.tfstate`
  in the management account (versioned, encrypted, native lockfile — Terraform
  >= 1.10). Locally: `export AWS_PROFILE=mgt && terraform init`. Migrated from
  local state with all 17 resources; `terraform plan` showed no changes.
- **CI role permissions** (three inline policies on
  `GitHubActions-TaggingPolicy-Role`):
  - `OrganizationsTagPolicyManagement`: `CreatePolicy`, `UpdatePolicy`,
    `AttachPolicy`, `EnablePolicyType`, and Describe/List.
  - `OrganizationsReadForTerraform`: read-only calls the provider makes on
    refresh (`ListTagsForResource`, `ListTargetsForPolicy`, Describe*).
  - `TerraformStateAccess-TaggingPolicy`: `s3:ListBucket` on the bucket and
    `s3:GetObject`/`PutObject`/`DeleteObject` on `tagging-policy/*` (state and
    `.tflock`).
- **The CI role cannot detach or destroy.** It has **no** `DetachPolicy` or
  `DeletePolicy`. So rollback
  by detach/destroy must be done locally with the `mgt` profile, or the role's
  inline policy must be extended first. Forward changes (attach more, widen
  enforcement) work fine in CI.
- **The CI role itself is managed in code** in [`bootstrap/`](bootstrap/README.md)
  (separate stack, separate state, applied locally only). Do not edit the role
  in the console or CLI: any extra inline policy shows up as drift and is
  removed on the next bootstrap apply.
