output "role_arn" {
  description = "ARN to use as role-to-assume in .github/workflows/deploy-tag-policy.yml."
  value       = aws_iam_role.tagging_ci.arn
}
