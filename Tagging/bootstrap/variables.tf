variable "role_name" {
  description = "Name of the CI role assumed by the Deploy Tag Policy workflow."
  type        = string
  default     = "GitHubActions-TaggingPolicy-Role"
}

variable "github_repo" {
  description = "owner/repo allowed to assume the role (main branch only)."
  type        = string
  default     = "Dynmedia/shahriar-sajib"
}

variable "state_bucket" {
  description = "S3 bucket holding the Tagging/ Terraform state."
  type        = string
  default     = "dynmedia-terraform-state-660571558619"
}
