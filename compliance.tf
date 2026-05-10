# =============================================================================
# Backup Restore Testing & Audit Manager - Deployed in the backup account
# =============================================================================

# Restore testing plan - validates backups are restorable
resource "aws_backup_restore_testing_plan" "daily_validation" {
  provider            = aws.backup
  name                = "daily_restore_validation"
  schedule_expression = "cron(0 6 ? * * *)" # 06:00 UTC daily
  start_window_hours  = 2

  recovery_point_selection {
    algorithm             = "LATEST_WITHIN_WINDOW"
    include_vaults        = [aws_backup_vault.central.arn]
    recovery_point_types  = ["SNAPSHOT"]
    selection_window_days = 7
  }

  tags = {
    Name      = "daily-restore-validation"
    ManagedBy = "terraform"
  }
}

# Audit Manager framework - compliance reporting
resource "aws_backup_framework" "compliance" {
  provider = aws.backup
  name     = "central_backup_compliance"

  control {
    name = "BACKUP_RESOURCES_PROTECTED_BY_BACKUP_PLAN"
    scope {
      tags = {
        Backup = "true"
      }
    }
  }

  control {
    name = "BACKUP_RECOVERY_POINT_MINIMUM_RETENTION_CHECK"
    input_parameter {
      name  = "requiredRetentionDays"
      value = "7"
    }
  }

  control {
    name = "BACKUP_RECOVERY_POINT_ENCRYPTED"
  }

  control {
    name = "BACKUP_LAST_RECOVERY_POINT_CREATED"
    input_parameter {
      name  = "recoveryPointAgeUnit"
      value = "days"
    }
    input_parameter {
      name  = "recoveryPointAgeValue"
      value = "1"
    }
  }

  tags = {
    Name      = "central-backup-compliance"
    ManagedBy = "terraform"
  }
}
