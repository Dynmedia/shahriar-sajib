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

locals {
  # Value-constrained keys. enforced_for is attached to these when a resource
  # type is listed in var.enforced_resource_types.
  tag_value_sets = {
    Environment = ["production", "development", "integration", "staging", "sandbox", "shared", "security", "tools", "management", "sit"]
    Project     = ["networking", "connectivity", "shared-services", "security-hub", "audit", "log-archive", "infra-tools", "api-toolkit", "fast", "business-intelligence", "contentdesk", "mimir-fileflows", "blog", "account-factory"]
    CostCenter  = ["product-and-tech", "editorial-team"]
    Stage       = ["prod", "dev", "int", "staging"]
    Team        = ["dcc", "infra"]
  }

  # enforced_for block, emitted only when there is at least one resource type to
  # enforce on. Applied to every value-constrained key.
  enforced_for_block = length(var.enforced_resource_types) > 0 ? {
    "@@assign" = var.enforced_resource_types
  } : null

  # Owner is PRESENCE-ONLY (no value set), so it can never be value-enforced.
  # It is declared as a key with no tag_value / enforced_for.
  owner_statement = {
    Owner = {
      tag_key = { "@@assign" = "Owner" }
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
