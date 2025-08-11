provider "aws" {
  alias   = "mgmt"
  region  = var.region
  profile = var.management_account_profile
}
