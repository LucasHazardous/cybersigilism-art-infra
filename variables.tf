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

variable "github_token" {
  description = "Github personal access token for project repository"
  type        = string
  sensitive   = true
}

variable "github_repository_url" {
  description = "Github repository with static website source code"
  type        = string
}
