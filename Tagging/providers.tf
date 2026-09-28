terraform {
  required_version = ">= 1.10.0" # use_lockfile in backend.tf needs 1.10+

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Management account provider — organization tag policies are created and
# attached from the management account (660571558619).
#
# profile is set from var.management_account_profile for LOCAL runs, but is
# omitted (null) when that variable is empty so the default credential chain is
# used. In CI, the GitHubActions-TaggingPolicy-Role supplies ambient credentials
# via OIDC and no profile exists — so the workflow sets
# management_account_profile="" to fall through to the role.
provider "aws" {
  alias   = "mgmt"
  region  = var.region
  profile = var.management_account_profile != "" ? var.management_account_profile : null
}
