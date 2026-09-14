# Tagging — Organization Tag Policy (preventive control)

Terraform for the Dyn six-key tagging standard as an **AWS Organizations tag
policy**, managed from the **management account** (`660571558619`).

This is the **preventive** complement to the **detective** AWS Config rules that
live in the `security-account` repo:

| | AWS Config rules (security-account) | Tag policy (this folder) |
|---|---|---|
| Acts | after a resource exists | at tagging time |
| Can it block? | No — reports only | **Yes** — blocks non-compliant tag *values* on enforced resource types |
| Checks presence (key missing)? | Yes | **No** — untagged resources are not evaluated |
| Checks value (wrong value)? | Yes | Yes |
| Scope control | exclusion list of account IDs | **attachment topology** (see below) |

The two use the **same six keys and allowed values**, so they agree.

---

## What this does and does NOT do

- **Does:** block a tagging operation that sets a value outside the allowed list,
  for the resource types in `enforced_resource_types`, on the value-constrained
  keys (`Environment`, `Project`, `CostCenter`, `Stage`, `Team`).
- **Does NOT:** stop untagged resources. AWS does not evaluate untagged resources
  (or keys not in the policy) against a tag policy. Blocking *creation of
  untagged resources* requires a Service Control Policy — deliberately out of
  scope here.
- **`Owner`** is presence-only (no value set), so it is declared but never
  value-enforced.

---

## The six keys

| Key | Allowed values | Enforced? |
|---|---|---|
| `Owner` | any (presence only) | never (no value set) |
| `Environment` | production, development, integration, staging, sandbox, shared, security, tools, management, sit | when a resource type is in `enforced_resource_types` |
| `Project` | networking, connectivity, shared-services, security-hub, audit, log-archive, infra-tools, api-toolkit, fast, business-intelligence, contentdesk, mimir-fileflows, blog, account-factory | same |
| `CostCenter` | product-and-tech, editorial-team | same |
| `Stage` | prod, dev, int, staging | same |
| `Team` | dcc, infra | same |

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

## Phased rollout

Each phase is a small change to `attach_target_ids` and/or
`enforced_resource_types`. Gate each on the previous being proven.

1. **Phase 1 (default in this code): pilot.** Attach to **Sandbox-Managed**
   only; enforce `ec2:instance`, `ec2:volume`. Nine sandbox accounts, no
   production impact, avoids all six exclusions. Optionally set
   `enforced_resource_types = []` for a first apply that attaches but blocks
   nothing (observe the effective policy before enforcing).
2. **Phase 2:** widen `enforced_resource_types` (e.g. `dynamodb:table`, other
   supported types), still Sandbox-Managed only.
3. **Phase 3:** add Bucket-A OUs to `attach_target_ids` one at a time,
   highest-tolerance first (Tools, Workloads) before customer-facing.
4. **Phase 4:** add the two Contentdesk mimir accounts by ID.

Only resource types that support tag-policy enforcement are valid in
`enforced_resource_types`.

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

### REQUIRED before first apply: import the existing policy
A policy `Organization-Wide-Tagging` (`p-957g5s40o6`) already exists by hand and
is attached to nothing. AWS Organizations **rejects duplicate policy names**, so
a first `apply` without importing will **FAIL** with a name-collision error
(verified: a plan proposes to *create* `Organization-Wide-Tagging`, which the
API will refuse because the name is taken).

Import it into state first so Terraform manages the existing policy in place:
```bash
cd Tagging
AWS_PROFILE=mgt terraform init
AWS_PROFILE=mgt terraform import aws_organizations_policy.tagging p-957g5s40o6
```
After import, `terraform plan` will show an in-place **update** to the policy
content (adding `enforced_for`) plus the **new attachment** to Sandbox-Managed —
no create, no destroy.

`policy_name` defaults to `Organization-Wide-Tagging` to match the existing
policy. Alternatives if you do NOT want to adopt it:
- Rename via `policy_name` to create a separate, new policy (the old one stays
  inert) — not recommended, leaves two policies.

> The import is a local, one-time step run with the `mgt` profile. The CI OIDC
> role can create/update/attach but **cannot** import into remote state (there is
> no remote state here yet — state is local, as in backup-solution). Decide state
> location before relying on CI for apply; see "State" note below.

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

- **State is local** (mirrors `backup-solution`, which has no backend). That is
  fine for a `mgt`-profile local apply, but CI cannot share local state. If you
  want CI to be the source of truth, add a remote backend (S3 in the management
  account, e.g. `dynmedia-terraform-state-660571558619`) **before** first apply,
  and do the one-time `terraform import` against that backend.
- **The CI role cannot detach or destroy.** `GitHubActions-TaggingPolicy-Role`
  grants `CreatePolicy`, `UpdatePolicy`, `AttachPolicy`, `Describe/List`, and
  `EnablePolicyType` — but **not** `DetachPolicy` or `DeletePolicy`. So rollback
  by detach/destroy must be done locally with the `mgt` profile, or the role's
  inline policy must be extended first. Forward changes (attach more, widen
  enforcement) work fine in CI.
