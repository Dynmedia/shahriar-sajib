# Remote state for the organization tag policy (management account).
#
# State previously lived only on the machine that ran the apply. It records the
# live policy p-957g5s40o6 and its 16 attachments; losing it would mean
# re-importing all 17 resources by hand before any further change.
#
# Bucket: management account 660571558619, versioned, SSE-AES256, public access
# blocked. Key is namespaced so it cannot collide with the iam-identity-center
# stacks in the same bucket. use_lockfile = native S3 locking (Terraform >= 1.10),
# no DynamoDB table needed.
#
# profile is not set here: locally, export AWS_PROFILE=mgt before `terraform init`;
# in CI the OIDC role supplies credentials.
terraform {
  backend "s3" {
    bucket       = "dynmedia-terraform-state-660571558619"
    key          = "tagging-policy/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }
}
