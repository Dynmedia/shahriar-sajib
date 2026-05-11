# =============================================================================
# Organization Backup Policy - Managed from the management account
# =============================================================================

locals {
  central_vault_arn = aws_backup_vault.central.arn

  backup_policy_json = jsonencode({
    "plans" : {
      "DailyBackupPlan" : {
        "regions" : {
          "@@assign" : [var.region]
        },
        "rules" : {
          "DailyRule" : {
            "schedule_expression" : { "@@assign" : var.backup_schedule },
            "start_backup_window_minutes" : { "@@assign" : "60" },
            "complete_backup_window_minutes" : { "@@assign" : "180" },
            "target_backup_vault_name" : { "@@assign" : "Default" },
            "lifecycle" : {
              "delete_after_days" : { "@@assign" : "30" }
            },
            "copy_actions" : {
              "${local.central_vault_arn}" : {
                "target_backup_vault_arn" : { "@@assign" : "${local.central_vault_arn}" },
                "lifecycle" : {
                  "delete_after_days" : { "@@assign" : 365 }
                }
              }
            }
          }
        },
        "selections" : {
          "resources" : {
            "BackupTagSelection" : {
              "iam_role_arn" : { "@@assign" : "arn:aws:iam::$account:role/service-role/AWSBackupDefaultServiceRole" },

              "conditions" : {
                "string_equals" : {
                  "BackupTrue" : {
                    "condition_key" : { "@@assign" : "aws:ResourceTag/Backup" },
                    "condition_value" : { "@@assign" : "true" }
                  }
                }
              }
            }
          }
        }
      }
    }
  })
}

resource "aws_organizations_policy" "backup_policy" {
  provider    = aws.mgmt
  name        = "Org-Backup-Policy-Central"
  description = "Back up tagged resources (S3, DynamoDB, RDS, OpenSearch, EFS) in member accounts and copy to central vault."
  type        = "BACKUP_POLICY"
  content     = local.backup_policy_json
}

resource "aws_organizations_policy_attachment" "backup_policy_to_ous" {
  provider  = aws.mgmt
  for_each  = toset(var.ou_ids)
  policy_id = aws_organizations_policy.backup_policy.id
  target_id = each.value
}
