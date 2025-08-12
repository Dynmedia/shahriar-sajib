resource "aws_kms_key" "backup_kms" {
  provider                = aws.mgmt
  description             = "KMS key for central backup vault"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

resource "aws_backup_vault" "central" {
  provider     = aws.mgmt
  name         = var.central_backup_vault_name
  kms_key_arn  = aws_kms_key.backup_kms.arn
}

resource "aws_backup_vault_lock_configuration" "vault_lock" {
  provider                  = aws.mgmt
  count                     = var.enable_vault_lock ? 1 : 0
  backup_vault_name         = aws_backup_vault.central.name
  min_retention_days        = 10
  max_retention_days        = 365
  changeable_for_days       = 4
}

resource "aws_backup_vault_policy" "central_copyin_policy" {
  provider          = aws.mgmt
  backup_vault_name = aws_backup_vault.central.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowOrgToCopyIntoVault",
        Effect    = "Allow",
        Principal = "*",
        Action    = "backup:CopyIntoBackupVault",
        Resource  = aws_backup_vault.central.arn,
        Condition = {
          StringEquals = {
            "aws:PrincipalOrgID" = var.organization_id
          }
        }
      }
    ]
  })
}
