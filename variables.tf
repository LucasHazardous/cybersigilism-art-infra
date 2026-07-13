variable "project_tag" {
  description = "Value for Project tag"
  type        = string
  default     = "cybersigilism-art"
}

variable "project_region" {
  description = "Project region"
  type        = string
  default     = "eu-west-3"
}

variable "spaceship_api_key" {
  description = "API Key for Spaceship DNS Registrar"
  type        = string
  sensitive   = true
}

variable "spaceship_api_secret" {
  description = "API Key for Spaceship DNS Registrar"
  type        = string
  sensitive   = true
}

variable "domain_name" {
  description = "Domain name for this project"
  type        = string
  default     = "cybersigilism.art"
}

variable "website_bucket_name" {
  description = "Name for S3 bucket with static website"
  type        = string
  default     = "cybersigilism-art-website"
}

variable "codebuild_name" {
  description = "Name for CodeBuild project attached to CodeCommit"
  type        = string
  default     = "cybersigilism-art-website"
}

variable "github_token" {
  description = "Github personal access token for project repository"
  type        = string
  sensitive   = true
}

variable "github_repository_url" {
  description = "Github repository with static website source code"
  type        = string
}
