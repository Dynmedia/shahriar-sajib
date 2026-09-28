# CI deploy role for the organization tag policy (Tagging/).
#
# WHY A SEPARATE STACK: this role is what the "Deploy Tag Policy" workflow
# assumes. A role must not manage its own permissions, otherwise anyone who can
# run the workflow could grant the role more access. So this stack is applied
# LOCALLY with the mgt profile only, never from CI, and changes go through PR
# review.
#
# The role was originally created by hand (2025-12-07). Everything below was
# imported as-is; the first plan after import showed no changes.

# Shared, account-wide GitHub OIDC provider (also used by other roles, e.g.
# GitHubActionsPlanRole). Referenced only - NOT managed here.
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

locals {
  bucket_arn = "arn:aws:s3:::${var.state_bucket}"
}

resource "aws_iam_role" "tagging_ci" {
  name                 = var.role_name
  description          = "Role for GitHub Actions to deploy AWS Organizations tagging policies"
  max_session_duration = 3600

  # Only the main branch of the configured repo may assume the role.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = data.aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:ref:refs/heads/main"
        }
      }
    }]
  })
}

# Forward-only tag policy management. Deliberately NO DetachPolicy/DeletePolicy:
# rollback by detach/destroy stays a local, human action with the mgt profile.
resource "aws_iam_role_policy" "tag_policy_management" {
  name = "OrganizationsTagPolicyManagement"
  role = aws_iam_role.tagging_ci.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "organizations:ListRoots",
        "organizations:EnablePolicyType",
        "organizations:CreatePolicy",
        "organizations:UpdatePolicy",
        "organizations:AttachPolicy",
        "organizations:ListPolicies",
        "organizations:ListPoliciesForTarget",
        "organizations:DescribePolicy",
        "organizations:ListOrganizationalUnitsForParent",
      ]
      Resource = "*"
    }]
  })
}

# Read-only calls the AWS provider makes while refreshing the policy and its
# attachments (ListTagsForResource was the cause of the first CI plan failure).
resource "aws_iam_role_policy" "org_read_for_terraform" {
  name = "OrganizationsReadForTerraform"
  role = aws_iam_role.tagging_ci.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "TerraformRefreshReadOnly"
      Effect = "Allow"
      Action = [
        "organizations:ListTagsForResource",
        "organizations:ListTargetsForPolicy",
        "organizations:DescribeOrganization",
        "organizations:DescribeOrganizationalUnit",
        "organizations:DescribeAccount",
      ]
      Resource = "*"
    }]
  })
}

# Terraform state for Tagging/ only. The bootstrap state for THIS stack lives
# under tagging-policy-bootstrap/, which this prefix does not match.
resource "aws_iam_role_policy" "state_access" {
  name = "TerraformStateAccess-TaggingPolicy"
  role = aws_iam_role.tagging_ci.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "ListStatePrefix"
        Effect    = "Allow"
        Action    = "s3:ListBucket"
        Resource  = local.bucket_arn
        Condition = { StringLike = { "s3:prefix" = ["tagging-policy/*", "tagging-policy"] } }
      },
      {
        Sid      = "ReadWriteStateAndLock"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "${local.bucket_arn}/tagging-policy/*"
      },
    ]
  })
}

# Makes the three policies above the ONLY inline policies on the role. Any
# inline policy added by hand in the console/CLI shows up as drift in plan and
# is removed on the next apply.
resource "aws_iam_role_policies_exclusive" "tagging_ci" {
  role_name = aws_iam_role.tagging_ci.name
  policy_names = [
    aws_iam_role_policy.tag_policy_management.name,
    aws_iam_role_policy.org_read_for_terraform.name,
    aws_iam_role_policy.state_access.name,
  ]
}

# Same for managed-policy attachments: the role must have none.
resource "aws_iam_role_policy_attachments_exclusive" "tagging_ci" {
  role_name   = aws_iam_role.tagging_ci.name
  policy_arns = []
}
