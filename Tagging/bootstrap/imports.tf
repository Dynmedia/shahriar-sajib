# One-time adoption of the hand-made role. Import blocks are idempotent: once
# the resources are in state they are no-ops, so they can stay as a record.

import {
  to = aws_iam_role.tagging_ci
  id = "GitHubActions-TaggingPolicy-Role"
}

import {
  to = aws_iam_role_policy.tag_policy_management
  id = "GitHubActions-TaggingPolicy-Role:OrganizationsTagPolicyManagement"
}

import {
  to = aws_iam_role_policy.org_read_for_terraform
  id = "GitHubActions-TaggingPolicy-Role:OrganizationsReadForTerraform"
}

import {
  to = aws_iam_role_policy.state_access
  id = "GitHubActions-TaggingPolicy-Role:TerraformStateAccess-TaggingPolicy"
}

import {
  to = aws_iam_role_policies_exclusive.tagging_ci
  id = "GitHubActions-TaggingPolicy-Role"
}

import {
  to = aws_iam_role_policy_attachments_exclusive.tagging_ci
  id = "GitHubActions-TaggingPolicy-Role"
}
