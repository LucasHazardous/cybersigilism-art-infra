variable "spaceship_api_key" {
  description = "API Key for Spaceship DNS Registrar"
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "spaceship_api_secret" {
  description = "API Key for Spaceship DNS Registrar"
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "github_token" {
  description = "Github personal access token for project repository"
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "github_repository_url" {
  description = "Github repository with static website source code"
  type        = string
}

variable "admin_email" {
  description = "Admin e-mail address that will be used to send notifications, ex. budget alerts"
  type        = string
  sensitive   = true
}
