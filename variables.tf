variable "region" {
  type    = string
  default = "us-east-1"
}

variable "organization_id" {
  default = "o-zh0iuh87kj"
}

variable "management_account_profile" {
  description = "AWS CLI profile for management/central account"
  type        = string
}

variable "central_account_id" {
  default = "515645413120"
}

variable "ou_ids" {
  type    = list(string)
  default = ["ou-c7dt-bn8vj0b5", "ou-c7dt-398jbgv3"]
}

variable "central_backup_vault_name" {
  default = "central-backup-vault"
}

variable "enable_vault_lock" {
  default = true
}
