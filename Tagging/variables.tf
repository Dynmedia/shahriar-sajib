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
    for local runs, mirroring backup-solution. Set to "" to use the default
    credential chain (CI).
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

    ORG-WIDE minus the six excluded accounts. Because tag policies cannot
    express exclusions, org-wide-minus-six is built as: attach to every OU with
    no excluded account inside, plus attach individually to the two monitored
    accounts in the Contentdesk OU, plus aws_mmo at root level. The excluded
    accounts (dyn-contentdesk-*, dyn-deltatreaxis-prod, voscustomer1002.vos,
    dyn-mmo) are covered by never attaching to them or to any OU above them.
    Never attach to the root -- validation below refuses it.
  EOT
  type        = list(string)
  default = [
    # Whole-OU attachments (no excluded account inside):
    "ou-rzmo-x0s5egxb", # AFT
    "ou-rzmo-yjugum6z", # Braze
    "ou-rzmo-xuv5mooa", # Business-Intelligence
    "ou-rzmo-b9fl9bvd", # DynBlog
    "ou-rzmo-3xaoy7pi", # DynCustomerControl
    "ou-rzmo-nqhhq24i", # FX-Digital
    "ou-rzmo-8qij8v74", # Infrastructure
    "ou-rzmo-qfmzlwhq", # Sandbox
    "ou-rzmo-bjyh9b48", # Sandbox-Managed
    "ou-rzmo-6aq0nycd", # Security
    "ou-rzmo-3fzvwamr", # Tooling
    "ou-rzmo-b8kwzyok", # Tools
    "ou-rzmo-4aok8egi", # Workloads
    # Split OU Contentdesk: attach ONLY the 2 monitored accounts, never the OU
    # (it also holds the 3 excluded dyn-contentdesk-* accounts):
    "386372465922", # dyn-mimir-fileflows-prod
    "241533154876", # dyn-mimir-fileflows-staging
    # Split OU DeltatreAxis: NOT attached (both accounts are excluded).
    # Root-level account aws_mmo: attached individually (root must not be
    # attached); dyn-mmo is excluded so it is omitted:
    "992382361990", # aws_mmo
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
    time (the tag policy enforced_for field), applied to the value-constrained
    keys (Environment, Project, CostCenter, Stage, Team).

    IMPORTANT -- what enforcement does and does NOT do:
      * It BLOCKS a tagging operation that sets a value outside the allowed list,
        for the resource types listed here.
      * It does NOT block untagged resources. A resource created with no tags,
        or without the key, is not evaluated. (That would require an SCP.)
      * "All AWS resources" is NOT possible. AWS supports enforcement for a
        fixed subset of services only and offers no global wildcard. This list
        is every service exposing a <service>:ALL_SUPPORTED enforcement token,
        i.e. the broadest enforcement AWS allows.

    HIGH BLAST RADIUS. Combined with the organization-wide attach_target_ids,
    this blocks non-compliant tag VALUES across every monitored account for all
    the services below. A create/tag operation setting e.g. Environment=dev on
    an S3 bucket, RDS instance, Lambda function, etc. is REJECTED at the API.
    Announce to account owners before applying; expect breakage where existing
    automation sets non-conforming values. Set to [] to attach but block
    nothing (detect-only) if you want to observe first.
  EOT
  type        = list(string)

  # Every service exposing <service>:ALL_SUPPORTED with enforcement = Yes in the
  # AWS "Services and resource types that support enforcement" reference.
  # Services without an ALL_SUPPORTED enforcement token (e.g. iam, glue,
  # guardduty, securitylake, macie2) are intentionally omitted: they cannot be
  # enforced this way and an unsupported token fails the API.
  default = [
    "acm:ALL_SUPPORTED",
    "acm-pca:ALL_SUPPORTED",
    "athena:ALL_SUPPORTED",
    "backup:ALL_SUPPORTED",
    "cloudtrail:ALL_SUPPORTED",
    "cloudwatch:ALL_SUPPORTED",
    "codebuild:ALL_SUPPORTED",
    "codecommit:ALL_SUPPORTED",
    "codepipeline:ALL_SUPPORTED",
    "config:ALL_SUPPORTED",
    "dms:ALL_SUPPORTED",
    "dynamodb:ALL_SUPPORTED",
    "ec2:ALL_SUPPORTED",
    "ecr:ALL_SUPPORTED",
    "ecs:ALL_SUPPORTED",
    "eks:ALL_SUPPORTED",
    "elasticache:ALL_SUPPORTED",
    "elasticbeanstalk:ALL_SUPPORTED",
    "elasticfilesystem:ALL_SUPPORTED",
    "elasticmapreduce:ALL_SUPPORTED",
    "entityresolution:ALL_SUPPORTED",
    "events:ALL_SUPPORTED",
    "firehose:ALL_SUPPORTED",
    "fsx:ALL_SUPPORTED",
    "healthlake:ALL_SUPPORTED",
    "internetmonitor:ALL_SUPPORTED",
    "kinesisanalytics:ALL_SUPPORTED",
    "kms:ALL_SUPPORTED",
    "lambda:ALL_SUPPORTED",
    "mq:ALL_SUPPORTED",
    "network-firewall:ALL_SUPPORTED",
    "oam:ALL_SUPPORTED",
    "omics:ALL_SUPPORTED",
    "organizations:ALL_SUPPORTED",
    "pipes:ALL_SUPPORTED",
    "ram:ALL_SUPPORTED",
    "rbin:ALL_SUPPORTED",
    "rds:ALL_SUPPORTED",
    "redshift:ALL_SUPPORTED",
    "redshift-serverless:ALL_SUPPORTED",
    "resource-groups:ALL_SUPPORTED",
    "route53:ALL_SUPPORTED",
    "route53resolver:ALL_SUPPORTED",
    "s3:ALL_SUPPORTED",
    "scheduler:ALL_SUPPORTED",
    "secretsmanager:ALL_SUPPORTED",
    "sns:ALL_SUPPORTED",
    "sqs:ALL_SUPPORTED",
    "ssm:ALL_SUPPORTED",
    "states:ALL_SUPPORTED",
    "transfer:ALL_SUPPORTED",
    "wisdom:ALL_SUPPORTED",
    "workspaces:ALL_SUPPORTED",
  ]
}

variable "organization_id" {
  description = "AWS Organizations ID (for reference/outputs)."
  type        = string
  default     = "o-ppkzjmywn4"
}
