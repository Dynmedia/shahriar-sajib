# =============================================================================
# Outputs
# =============================================================================

output "central_backup_vault_arn" {
  description = "ARN of the central backup vault"
  value       = aws_backup_vault.central.arn
}

output "central_backup_vault_name" {
  description = "Name of the central backup vault"
  value       = aws_backup_vault.central.name
}

output "backup_kms_key_arn" {
  description = "ARN of the KMS key used for backup encryption"
  value       = aws_kms_key.backup_kms.arn
}

output "backup_policy_id" {
  description = "ID of the organization backup policy"
  value       = aws_organizations_policy.backup_policy.id
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for backup failure notifications"
  value       = aws_sns_topic.backup_notifications.arn
}

# Cost estimation outputs
output "estimated_monthly_cost" {
  description = "Estimated monthly backup storage cost (USD)"
  value = format("$%.2f",
    (var.estimated_s3_data_gb * 0.05) +
    (var.estimated_dynamodb_data_gb * 0.10) +
    (var.estimated_rds_data_gb * 0.095) +
    (var.estimated_opensearch_data_gb * 0.05) +
    (var.estimated_efs_data_gb * 0.05) +
    ((var.estimated_s3_data_gb + var.estimated_dynamodb_data_gb + var.estimated_rds_data_gb + var.estimated_opensearch_data_gb + var.estimated_efs_data_gb) * 0.02)
  )
}

output "estimated_annual_cost" {
  description = "Estimated annual backup storage cost (USD)"
  value = format("$%.2f",
    ((var.estimated_s3_data_gb * 0.05) +
      (var.estimated_dynamodb_data_gb * 0.10) +
      (var.estimated_rds_data_gb * 0.095) +
      (var.estimated_opensearch_data_gb * 0.05) +
      (var.estimated_efs_data_gb * 0.05) +
    ((var.estimated_s3_data_gb + var.estimated_dynamodb_data_gb + var.estimated_rds_data_gb + var.estimated_opensearch_data_gb + var.estimated_efs_data_gb) * 0.02)) * 12
  )
}

output "cost_breakdown" {
  description = "Per-service monthly cost breakdown"
  value = {
    s3_storage_monthly         = format("$%.2f", var.estimated_s3_data_gb * 0.05)
    dynamodb_storage_monthly   = format("$%.2f", var.estimated_dynamodb_data_gb * 0.10)
    rds_storage_monthly        = format("$%.2f", var.estimated_rds_data_gb * 0.095)
    opensearch_storage_monthly = format("$%.2f", var.estimated_opensearch_data_gb * 0.05)
    efs_storage_monthly        = format("$%.2f", var.estimated_efs_data_gb * 0.05)
    cross_account_transfer     = format("$%.2f", (var.estimated_s3_data_gb + var.estimated_dynamodb_data_gb + var.estimated_rds_data_gb + var.estimated_opensearch_data_gb + var.estimated_efs_data_gb) * 0.02)
  }
}
