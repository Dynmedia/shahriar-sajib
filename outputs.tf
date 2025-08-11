output "central_backup_vault_arn" {
  value = aws_backup_vault.central.arn
}

output "backup_policy_id" {
  value = aws_organizations_policy.backup_policy.id
}
