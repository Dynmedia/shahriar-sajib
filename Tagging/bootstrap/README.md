# Tagging CI role (bootstrap)

Manages `GitHubActions-TaggingPolicy-Role`, the OIDC role assumed by the
**Deploy Tag Policy** workflow for `Tagging/`.

The role was created by hand in December 2025 and adopted into this stack by
import, with no changes to AWS.

## Why a separate stack

A role must not manage its own permissions. If the workflow could change this
role, anyone able to run the workflow could grant it more access. So:

- **Applied locally only**, with the `mgt` profile. CI never runs this folder
  (the workflow's working directory is `Tagging/`, and Terraform does not
  recurse into subfolders).
- **Own state**, at `s3://dynmedia-terraform-state-660571558619/tagging-policy-bootstrap/terraform.tfstate`.
  This is outside the `tagging-policy/` prefix the CI role can write, so CI
  cannot read or tamper with it (verified with the IAM policy simulator).
- **Changes go through PR review** like any other code.

## What it manages

| Resource | Purpose |
|---|---|
| `aws_iam_role` | Trust: GitHub OIDC, `repo:Dynmedia/shahriar-sajib`, `main` branch only |
| `OrganizationsTagPolicyManagement` | Create/update/attach tag policies. No detach/delete |
| `OrganizationsReadForTerraform` | Read-only calls the provider makes on refresh |
| `TerraformStateAccess-TaggingPolicy` | S3 state + lockfile under `tagging-policy/` |
| `*_exclusive` resources | These three are the only inline policies; no managed policies |

The GitHub OIDC provider is shared across the account, so it is only
referenced, not managed.

## Usage

```bash
cd Tagging/bootstrap
export AWS_PROFILE=mgt
terraform init
terraform plan     # expect "No changes" unless you edited something
terraform apply
```

The `import` blocks in `imports.tf` are no-ops now that the resources are in
state. They stay in the file as a record of the adoption.

The provider has `allowed_account_ids = ["660571558619"]`, so it refuses to
run against any other account.
