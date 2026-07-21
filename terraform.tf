terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.54"
    }

    spaceship = {
      source  = "namecheap/spaceship"
      version = "~> 0.4"
    }

    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }

    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.8"
    }
  }

  backend "s3" {
    bucket       = "cybersigilism-art-state"
    key          = "state/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }

  required_version = "~> 1.12"
}
