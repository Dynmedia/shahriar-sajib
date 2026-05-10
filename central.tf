# =============================================================================
# Central Backup Vault - Deployed in the dedicated backup account
# =============================================================================

# KMS key for encrypting backups in the central vault
resource "aws_kms_key" "backup_kms" {
  provider                = aws.backup
  description             = "KMS key for central backup vault encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowBackupAccountFullAdmin"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${var.backup_account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "AllowOrgAccountsBackupOperations"
        Effect    = "Allow"
        Principal = { AWS = "*" }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:PrincipalOrgID" = var.organization_id
          }
          StringLike = {
            "kms:ViaService" = "backup.*.amazonaws.com"
          }
        }
      },
      {
        Sid       = "DenyExternalAccess"
        Effect    = "Deny"
        Principal = { AWS = "*" }
        Action    = "kms:*"
        Resource  = "*"
        Condition = {
          StringNotEquals = {
            "aws:PrincipalOrgID" = var.organization_id
          }
          "Null" = {
            "aws:PrincipalOrgID" = "false"
          }
        }
      }
    ]
  })

  tags = {
    Name    = "central-backup-kms-key"
    Purpose = "backup-encryption"
  }
}

resource "aws_kms_alias" "backup_kms" {
  provider      = aws.backup
  name          = "alias/central-backup-key"
  target_key_id = aws_kms_key.backup_kms.key_id
}

# Central backup vault
resource "aws_backup_vault" "central" {
  provider    = aws.backup
  name        = var.central_backup_vault_name
  kms_key_arn = aws_kms_key.backup_kms.arn

  tags = {
    Name        = var.central_backup_vault_name
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

# Vault lock - compliance mode (irreversible after cooling-off period)
resource "aws_backup_vault_lock_configuration" "vault_lock" {
  provider            = aws.backup
  count               = var.enable_vault_lock ? 1 : 0
  backup_vault_name   = aws_backup_vault.central.name
  min_retention_days  = var.vault_lock_min_retention_days
  max_retention_days  = var.vault_lock_max_retention_days
  changeable_for_days = var.vault_lock_changeable_for_days
}

# Vault access policy - allow only org accounts to copy in
resource "aws_backup_vault_policy" "central_copyin_policy" {
  provider          = aws.backup
  backup_vault_name = aws_backup_vault.central.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowOrgToCopyIntoVault"
        Effect    = "Allow"
        Principal = "*"
        Action    = "backup:CopyIntoBackupVault"
        Resource  = "*"
        Condition = {
          StringEquals = {
            "aws:PrincipalOrgID" = var.organization_id
          }
        }
      },
      {
        Sid       = "DenyNonOrgCopyIntoVault"
        Effect    = "Deny"
        Principal = "*"
        Action    = "backup:CopyIntoBackupVault"
        Resource  = "*"
        Condition = {
          StringNotEquals = {
            "aws:PrincipalOrgID" = var.organization_id
          }
          "Null" = {
            "aws:PrincipalOrgID" = "false"
          }
        }
      }
    ]
  })
}

# SNS topic for backup failure notifications
resource "aws_sns_topic" "backup_notifications" {
  provider = aws.backup
  name     = "central-backup-notifications"

  tags = {
    Name      = "central-backup-notifications"
    ManagedBy = "terraform"
  }
}

resource "aws_sns_topic_policy" "backup_notifications" {
  provider = aws.backup
  arn      = aws_sns_topic.backup_notifications.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowBackupServicePublish"
        Effect    = "Allow"
        Principal = { Service = "backup.amazonaws.com" }
        Action    = "SNS:Publish"
        Resource  = aws_sns_topic.backup_notifications.arn
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "backup_email" {
  provider  = aws.backup
  count     = var.notification_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.backup_notifications.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# Vault notifications for failed jobs
resource "aws_backup_vault_notifications" "central" {
  provider          = aws.backup
  backup_vault_name = aws_backup_vault.central.name
  sns_topic_arn     = aws_sns_topic.backup_notifications.arn
  backup_vault_events = [
    "BACKUP_JOB_FAILED",
    "COPY_JOB_FAILED",
    "RESTORE_JOB_FAILED"
  ]
}
