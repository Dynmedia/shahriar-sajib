# Make the central account a delegated admin for AWS Backup
#resource "aws_organizations_delegated_administrator" "backup" {
#  provider             = aws.mgmt
#  account_id           = var.central_account_id
#  service_principal    = "backup.amazonaws.com"
#}



locals {
  central_vault_arn = aws_backup_vault.central.arn

  backup_policy_json = jsonencode({
    "plans" : {
      "DailyBackupPlan" : {
        "regions" : {
          "@@assign" : ["us-east-1"]
        },
        "rules" : {
          "DailyRule" : {
            "schedule_expression" : { "@@assign" : "cron(0 * ? * * *)" },  # Daily
            "start_backup_window_minutes" : { "@@assign" : "60" },
            "complete_backup_window_minutes" : { "@@assign" : "180" },
            "target_backup_vault_name" : { "@@assign" : "Default" },
            "lifecycle" : {
              "delete_after_days" : { "@@assign" : "1" }
            },
            "copy_actions" : {
              "${local.central_vault_arn}" : {
                "target_backup_vault_arn" : { "@@assign" : "${local.central_vault_arn}" }
              }
            }
          }
        },
        "selections" : {
          "resources" : {
            "TagAndTypeSelection" : {
              "iam_role_arn" : { "@@assign" : "arn:aws:iam::$account:role/service-role/AWSBackupDefaultServiceRole" },

              # Include only these resource types:
              "resource_types" : {
                "@@assign" : [
                  "arn:aws:ec2:*:*:volume/*",         # EBS volumes
                  "arn:aws:ec2:*:*:instance/*",       # EC2 instances
                  "arn:aws:rds:*:*:db:*",             # RDS DBs
                  "arn:aws:dynamodb:*:*:table/*",     # DynamoDB tables
                  "arn:aws:s3:::*"                    # S3 buckets
                ]
              },

              # Require Backup=true
              "conditions" : {
                "string_equals" : {
                  "BackupTrue" : {
                    "condition_key"   : { "@@assign" : "aws:ResourceTag/Backup" },
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
  name        = "Org-Backup-Policy-CentralCopy"
  description = "Back up tagged resources in member accounts and copy to central vault."
  type        = "BACKUP_POLICY"
  content     = local.backup_policy_json
}

resource "aws_organizations_policy_attachment" "backup_policy_to_ous" {
  provider  = aws.mgmt
  for_each  = toset(var.ou_ids)
  policy_id = aws_organizations_policy.backup_policy.id
  target_id = each.value
}
