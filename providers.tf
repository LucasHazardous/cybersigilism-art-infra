provider "aws" {
  region = var.project_region

  default_tags {
    tags = {
      Project = var.project_tag
    }
  }
}

provider "aws" {
  alias  = "cloudfront_acm"
  region = "us-east-1"

  default_tags {
    tags = {
      Project = var.project_tag
    }
  }
}

provider "spaceship" {
  api_key    = var.spaceship_api_key
  api_secret = var.spaceship_api_secret
}
