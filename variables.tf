variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "organization_id" {
  default = "o-ppkzjmywn4"
}

variable "management_account_profile" {
  description = "AWS CLI profile for management/central account"
  type        = string
}

variable "central_account_id" {
  default = "660571558619"
}

variable "ou_ids" {
  type    = list(string)
  default = ["ou-rzmo-qfmzlwhq", "ou-rzmo-bjyh9b48"]
}

variable "central_backup_vault_name" {
  default = "central-backup-vault"
}

variable "enable_vault_lock" {
  default = true
}
