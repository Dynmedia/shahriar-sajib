variable "region" {
  description = "AWS region for all backup resources"
  type        = string
  default     = "eu-central-1"
}

variable "organization_id" {
  description = "AWS Organizations ID"
  type        = string
  default     = "o-ppkzjmywn4"
}

variable "management_account_profile" {
  description = "AWS CLI profile for the management account"
  type        = string
}

variable "backup_account_profile" {
  description = "AWS CLI profile for the dedicated backup account"
  type        = string
}

variable "backup_account_id" {
  description = "AWS account ID for the dedicated backup account"
  type        = string
  default     = "296297841611"
}

variable "ou_ids" {
  description = "Organizational Unit IDs to attach the backup policy to"
  type        = list(string)
  default = [
    "ou-rzmo-qfmzlwhq", # Sandbox
    "ou-rzmo-bjyh9b48", # Sandbox-Managed
    "ou-rzmo-b9fl9bvd"  # DynBlog
  ]
}

variable "central_backup_vault_name" {
  description = "Name of the central backup vault"
  type        = string
  default     = "central-backup-vault"
}

variable "enable_vault_lock" {
  description = "Enable vault lock in compliance mode (irreversible after cooling-off period)"
  type        = bool
  default     = true
}

variable "vault_lock_min_retention_days" {
  description = "Minimum retention period enforced by vault lock"
  type        = number
  default     = 7
}

variable "vault_lock_max_retention_days" {
  description = "Maximum retention period enforced by vault lock"
  type        = number
  default     = 365
}

variable "vault_lock_changeable_for_days" {
  description = "Cooling-off period in days before vault lock becomes irreversible"
  type        = number
  default     = 3
}

variable "local_retention_days" {
  description = "Number of days to retain local backups in member accounts"
  type        = number
  default     = 30
}

variable "central_retention_days" {
  description = "Number of days to retain backups in the central vault"
  type        = number
  default     = 365
}

variable "backup_schedule" {
  description = "Cron expression for backup schedule (UTC)"
  type        = string
  default     = "cron(0 2 ? * * *)"
}

variable "backup_start_window_minutes" {
  description = "Minutes allowed for backup job to start"
  type        = number
  default     = 60
}

variable "backup_completion_window_minutes" {
  description = "Minutes allowed for backup job to complete"
  type        = number
  default     = 180
}

# Cost estimation variables
variable "estimated_s3_data_gb" {
  description = "Estimated total S3 data size in GB for cost calculation"
  type        = number
  default     = 0
}

variable "estimated_dynamodb_data_gb" {
  description = "Estimated total DynamoDB data size in GB for cost calculation"
  type        = number
  default     = 0
}

variable "estimated_rds_data_gb" {
  description = "Estimated total RDS data size in GB for cost calculation"
  type        = number
  default     = 0
}

variable "estimated_opensearch_data_gb" {
  description = "Estimated total OpenSearch data size in GB for cost calculation"
  type        = number
  default     = 0
}

variable "estimated_efs_data_gb" {
  description = "Estimated total EFS data size in GB for cost calculation"
  type        = number
  default     = 0
}

# SNS notification
variable "notification_email" {
  description = "Email address for backup failure notifications (leave empty to skip)"
  type        = string
  default     = ""
}
