output "tag_policy_id" {
  description = "ID of the organization tag policy."
  value       = aws_organizations_policy.tagging.id
}

output "tag_policy_arn" {
  description = "ARN of the organization tag policy."
  value       = aws_organizations_policy.tagging.arn
}

output "attached_targets" {
  description = "Targets (OU/account ids) the tag policy is attached to."
  value       = sort(var.attach_target_ids)
}

output "enforcement_summary" {
  description = "What is blocked vs merely reported."
  value = length(var.enforced_resource_types) > 0 ? {
    mode                    = "ENFORCING (blocks non-compliant values)"
    enforced_resource_types = sort(var.enforced_resource_types)
    enforced_keys           = ["Environment", "Project", "CostCenter", "Stage", "Team"]
    note                    = "Untagged resources are NOT blocked; only non-compliant VALUES on the listed types. Owner is presence-only and never value-enforced."
    } : {
    mode                    = "DETECT-ONLY (attached, nothing blocked)"
    enforced_resource_types = []
    enforced_keys           = []
    note                    = "Set enforced_resource_types to begin blocking non-compliant values."
  }
}
