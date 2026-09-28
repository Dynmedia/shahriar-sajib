terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Separate state from Tagging/. LOCAL ONLY: export AWS_PROFILE=mgt first.
  # Deliberately OUTSIDE the tagging-policy/ prefix: the CI role can write
  # there, and it must not be able to tamper with the state of its own role.
  backend "s3" {
    bucket       = "dynmedia-terraform-state-660571558619"
    key          = "tagging-policy-bootstrap/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "eu-central-1"

  # Guard against applying with the wrong profile.
  allowed_account_ids = ["660571558619"]
}
