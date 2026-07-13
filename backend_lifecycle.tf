data "aws_s3_bucket" "backend" {
  region = "us-east-1"
  bucket = "cybersigilism-art-state"
}

resource "aws_s3_bucket_lifecycle_configuration" "clean_backend_old_versions" {
  bucket = data.aws_s3_bucket.backend.bucket
  region = data.aws_s3_bucket.backend.region

  rule {
    id = "remove-noncurrent-tflock"

    filter {
      prefix = "state/terraform.tfstate.tflock"
    }

    noncurrent_version_expiration {
      noncurrent_days = 1
    }

    expiration {
      expired_object_delete_marker = true
    }

    status = "Enabled"
  }

  rule {
    id = "remove-noncurrent-tfstate"

    filter {
      prefix = "state/terraform.tfstate"
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }

    expiration {
      expired_object_delete_marker = true
    }

    status = "Enabled"
  }
}
