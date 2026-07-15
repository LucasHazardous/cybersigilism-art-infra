resource "aws_codebuild_project" "primary" {
  name          = local.codebuild_name
  service_role  = aws_iam_role.codebuild_role.arn
  build_timeout = 10

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/amazonlinux-x86_64-standard:6.0"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "BUCKET"
      value = aws_s3_bucket.website_bucket.bucket
    }
  }

  source {
    type     = "GITHUB"
    location = var.github_repository_url
    auth {
      type     = "SECRETS_MANAGER"
      resource = aws_secretsmanager_secret.github_token.arn
    }
    buildspec = <<-EOT
      version: 0.2
      phases:
        install:
          runtime-versions:
            nodejs: 22
          commands:
            - npm ci
        build:
          commands:
            - npm run build
        post_build:
          commands:
            - aws s3 sync dist/ "s3://$BUCKET" --delete
    EOT
  }

  source_version = "main"
}

resource "aws_codebuild_webhook" "cybersigilim_art_main" {
  project_name = aws_codebuild_project.primary.name
  build_type   = "BUILD"

  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PUSH"
    }
  }
}

data "aws_iam_policy_document" "codebuild" {
  statement {
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:*:*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.github_token.arn]
  }

  statement {
    effect  = "Allow"
    actions = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject", "s3:ListBucket"]
    resources = [
      aws_s3_bucket.website_bucket.arn,
      "${aws_s3_bucket.website_bucket.arn}/*",
    ]
  }
}

data "aws_iam_policy_document" "codebuild_assume" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "codebuild_role" {
  name               = "${local.codebuild_name}-codebuild"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume.json
}

resource "aws_iam_role_policy" "codebuild" {
  role   = aws_iam_role.codebuild_role.id
  policy = data.aws_iam_policy_document.codebuild.json
}

resource "aws_secretsmanager_secret" "github_token" {
  name = "cybersigilism-art-github-token"
}

resource "aws_secretsmanager_secret_version" "github_token" {
  secret_id = aws_secretsmanager_secret.github_token.id
  secret_string_wo = jsonencode({
    ServerType = "GITHUB"
    AuthType   = "PERSONAL_ACCESS_TOKEN"
    Token      = var.github_token
  })
  secret_string_wo_version = 1
}

resource "github_repository" "cybersigilism_art" {
  name       = "cybersigilism-art"
  visibility = "private"
}
