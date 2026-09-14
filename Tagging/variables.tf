variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "management_account_profile" {
  description = <<-EOT
    AWS CLI profile for the management account (660571558619). Organization tag
    policies can only be created/attached from the management account. In CI
    this is unused because the GitHub Actions OIDC role
    (GitHubActions-TaggingPolicy-Role) supplies credentials directly; it is here
    for local runs, mirroring backup-solution.
  EOT
  type        = string
  default     = "mgt"
}

variable "policy_name" {
  description = <<-EOT
    Name of the organization tag policy.

    Default matches the EXISTING hand-made policy 'Organization-Wide-Tagging'
    (p-957g5s40o6). If you import that policy into this state (recommended), keep
    this name so Terraform manages it in place rather than creating a duplicate.
    See README for the import command.
  EOT
  type        = string
  default     = "Organization-Wide-Tagging"
}

variable "attach_target_ids" {
  description = <<-EOT
    Organization targets (OU ids or account ids) the tag policy is attached to.

    Tag policies attach-and-inherit: they have NO exclusion list. Coverage is
    controlled purely by WHERE this attaches. To exclude an account you simply
    do not attach to it (or to any OU above it).

    PHASE 1 (default): Sandbox-Managed OU only. This is the safe pilot — 9
    sandbox accounts, no production impact, and it cleanly avoids all six
    excluded accounts (none live in this OU).

    Later phases add more OUs one at a time. The split OUs (Contentdesk,
    DeltatreAxis) and root-level dyn-mmo are handled by NEVER attaching to them;
    the two monitored Contentdesk accounts (mimir-fileflows prod/staging) would
    be attached individually by ID when their phase arrives. See README.
  EOT
  type        = list(string)
  default = [
    "ou-rzmo-bjyh9b48", # Sandbox-Managed (Phase 1 pilot)
  ]
  validation {
    condition     = length(var.attach_target_ids) > 0
    error_message = "attach_target_ids must not be empty: a tag policy attached to nothing has no effect."
  }
  validation {
    condition = alltrue([
      for t in var.attach_target_ids :
      can(regex("^(ou-[a-z0-9]{4,32}-[a-z0-9]{8,32}|r-[a-z0-9]{4,32}|[0-9]{12})$", t))
    ])
    error_message = "Each attach_target_ids entry must be an OU id (ou-xxxx-xxxxxxxx), the root (r-xxxx), or a 12-digit account id."
  }
  validation {
    condition     = alltrue([for t in var.attach_target_ids : !can(regex("^r-", t))])
    error_message = "Refusing to attach to the organization root: root attachment inherits to EVERY account including the six deliberately-excluded ones and the management account, with no way to except them. Attach to specific OUs/accounts instead."
  }
}

variable "enforced_resource_types" {
  description = <<-EOT
    Resource types for which non-compliant tag VALUES are BLOCKED at tagging
    time (the tag policy `enforced_for` field), applied to the value-constrained
    keys (Environment, Project, CostCenter, Stage, Team).

    IMPORTANT — what enforcement does and does NOT do:
      * It BLOCKS a tagging operation that sets a value outside the allowed list,
        for the resource types listed here.
      * It does NOT block untagged resources. A resource created with no tags,
        or without the key, is not evaluated. (That would require an SCP.)
      * Only resource types that support tag-policy enforcement are valid here.

    PHASE 1 (default): EC2 instances and volumes only — the lowest-surface
    starting point. Empty list = attached but DETECT-ONLY (nothing blocked),
    which is the safest possible first apply if you want to observe before
    enforcing.
  EOT
  type        = list(string)
  default = [
    "ec2:instance",
    "ec2:volume",
  ]
}

variable "organization_id" {
  description = "AWS Organizations ID (for reference/outputs)."
  type        = string
  default     = "o-ppkzjmywn4"
}
