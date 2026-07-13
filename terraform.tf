terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.54"
    }

    spaceship = {
      source  = "namecheap/spaceship"
      version = ">= 0.4.0"
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
