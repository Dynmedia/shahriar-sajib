# =============================================================================
# Organization Tag Policy — managed from the management account
# =============================================================================
# Governs the six-key Dyn tagging standard. This is the PREVENTIVE complement to
# the detective AWS Config rules in the security-account repo: Config reports
# after the fact; this tag policy can BLOCK a non-compliant tag VALUE at tagging
# time for the resource types in var.enforced_resource_types.
#
# It cannot block untagged resources (AWS does not evaluate untagged resources
# against a tag policy) — that is an SCP decision, deliberately out of scope.
#
# The six keys and their allowed values below MATCH the existing hand-made
# policy p-957g5s40o6 and the security-account Config rule exactly, so the two
# controls agree.
#
# ALL KEYS ARE LOWERCASE WITH A dyn- PREFIX (dyn-owner, dyn-environment,
# dyn-project, dyn-costcenter, dyn-stage, dyn-team, dyn-aiworkload). Tag
# policies are case-sensitive on the key spelling: `environment` or
# `Environment` is non-compliant, `dyn-environment` is compliant.
#
# Plus one OPTIONAL key: dyn-aiworkload (developer/product/platform). It is NOT part
# of the six-key "tag everything" standard — it classifies AI resources only and
# powers AI cost attribution. Like every tag-policy key it constrains VALUES when
# present and never forces presence.

locals {
  # Value-constrained keys. enforced_for is attached to these when a resource
  # type is listed in var.enforced_resource_types.
  #
  # The first five are the value-constrained members of the six-key Dyn standard
  # (dyn-owner is presence-only, below). dyn-aiworkload is DIFFERENT in intent: it is an
  # OPTIONAL AI-classification tag, applied only to AI resources, not part of the
  # "tag every resource" six-key standard. It sits here so that WHEN it is set,
  # its value is validated/enforced exactly like the others (a tag policy never
  # requires presence, so making it optional needs no special handling — an
  # untagged or dyn-aiworkload-less resource is simply not evaluated for it). It
  # feeds AI cost attribution (developer / product / platform).
  tag_value_sets = {
    "dyn-environment" = ["production", "development", "integration", "staging", "sandbox", "shared", "security", "tools", "management", "sit"]
    "dyn-project"     = ["networking", "connectivity", "shared-services", "security-hub", "audit", "log-archive", "infra-tools", "api-toolkit", "fast", "business-intelligence", "contentdesk", "mimir-fileflows", "blog", "account-factory"]
    "dyn-costcenter"  = ["product-and-tech", "editorial-team"]
    "dyn-stage"       = ["prod", "dev", "int", "staging"]
    "dyn-team"        = ["dcc", "infra"]
    "dyn-aiworkload"  = ["developer", "product", "platform"]
  }

  # enforced_for block, emitted only when there is at least one resource type to
  # enforce on. Applied to every value-constrained key.
  enforced_for_block = length(var.enforced_resource_types) > 0 ? {
    "@@assign" = var.enforced_resource_types
  } : null

  # dyn-owner is PRESENCE-ONLY (no value set), so it can never be value-enforced.
  # It is declared as a key with no tag_value / enforced_for.
  owner_statement = {
    "dyn-owner" = {
      tag_key = { "@@assign" = "dyn-owner" }
    }
  }

  # Build each value-constrained key's statement, conditionally adding
  # enforced_for.
  value_statements = {
    for key, values in local.tag_value_sets : key => merge(
      {
        tag_key   = { "@@assign" = key }
        tag_value = { "@@assign" = values }
      },
      local.enforced_for_block != null ? { enforced_for = local.enforced_for_block } : {}
    )
  }

  tag_policy_content = jsonencode({
    tags = merge(local.owner_statement, local.value_statements)
  })
}

resource "aws_organizations_policy" "tagging" {
  provider    = aws.mgmt
  name        = var.policy_name
  description = "Dyn six-key tagging standard. Value validation, with optional enforcement (blocking) per var.enforced_resource_types. Detective complement lives in the security-account AWS Config rules."
  type        = "TAG_POLICY"
  content     = local.tag_policy_content
}

resource "aws_organizations_policy_attachment" "tagging" {
  provider  = aws.mgmt
  for_each  = toset(var.attach_target_ids)
  policy_id = aws_organizations_policy.tagging.id
  target_id = each.value
}
