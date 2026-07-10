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

  required_version = "~> 1.12"
}
