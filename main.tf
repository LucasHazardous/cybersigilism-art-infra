resource "spaceship_domain" "cybersigilism_art" {
  domain = var.domain_name
  nameservers = {
    provider = "custom"
    hosts    = aws_route53_zone.primary.name_servers
  }
}

resource "aws_acm_certificate" "cert" {
  provider          = aws.cloudfront_acm
  domain_name       = var.domain_name
  validation_method = "DNS"
}

resource "aws_route53_record" "validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.primary.zone_id
}

resource "aws_acm_certificate_validation" "default" {
  provider                = aws.cloudfront_acm
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn]
}

resource "aws_codecommit_repository" "primary" {
  repository_name = var.codecommit_name
  description     = "Repository for cybersigilism.art website"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_route53_zone" "primary" {
  name = var.domain_name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket" "website_bucket" {
  bucket           = format("%s-%s-%s-an", var.website_bucket_name, data.aws_caller_identity.current.account_id, data.aws_region.current.region)
  bucket_namespace = "account-regional"
  force_destroy    = true
}

data "aws_iam_policy_document" "s3_cloudfront" {
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.website_bucket.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.s3_distribution.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "cloudfront" {
  bucket = aws_s3_bucket.website_bucket.id
  policy = data.aws_iam_policy_document.s3_cloudfront.json
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

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
  name               = "${var.codebuild_name}-codebuild"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume.json
}

data "aws_iam_policy_document" "codebuild" {
  statement {
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:*:*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["codecommit:GitPull"]
    resources = [aws_codecommit_repository.primary.arn]
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

resource "aws_iam_role_policy" "codebuild" {
  role   = aws_iam_role.codebuild_role.id
  policy = data.aws_iam_policy_document.codebuild.json
}

resource "aws_codebuild_project" "primary" {
  name          = var.codebuild_name
  service_role  = aws_iam_role.codebuild_role.arn
  build_timeout = 10

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "BUCKET"
      value = aws_s3_bucket.website_bucket.bucket
    }
  }

  source {
    type      = "CODECOMMIT"
    location  = aws_codecommit_repository.primary.clone_url_http
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

  source_version = "refs/heads/main"
}

resource "aws_cloudwatch_event_rule" "main_push" {
  name = "${var.codebuild_name}-main-push"

  event_pattern = jsonencode({
    source      = ["aws.codecommit"]
    detail-type = ["CodeCommit Repository State Change"]
    resources   = [aws_codecommit_repository.primary.arn]
    detail = {
      event         = ["referenceUpdated", "referenceCreated"]
      referenceType = ["branch"]
      referenceName = ["main"]
    }
  })
}

data "aws_iam_policy_document" "events_assume" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "events" {
  name               = "${var.codebuild_name}-events"
  assume_role_policy = data.aws_iam_policy_document.events_assume.json
}

data "aws_iam_policy_document" "cloudwatch" {
  statement {
    effect    = "Allow"
    actions   = ["codebuild:StartBuild"]
    resources = [aws_codebuild_project.primary.arn]
  }
}

resource "aws_iam_role_policy" "events" {
  role   = aws_iam_role.events.id
  policy = data.aws_iam_policy_document.cloudwatch.json
}

resource "aws_cloudwatch_event_target" "start_build" {
  rule     = aws_cloudwatch_event_rule.main_push.name
  arn      = aws_codebuild_project.primary.arn
  role_arn = aws_iam_role.events.arn
}

resource "aws_route53_record" "alias" {
  for_each = toset(["A", "AAAA"])

  zone_id = aws_route53_zone.primary.zone_id
  name    = var.domain_name
  type    = each.value

  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

resource "aws_cloudfront_origin_access_control" "default" {
  name                              = "default-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.website_bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.default.id
    origin_id                = aws_s3_bucket.website_bucket.id
  }

  aliases = [var.domain_name]

  enabled         = true
  is_ipv6_enabled = true

  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    target_origin_id = aws_s3_bucket.website_bucket.id

    viewer_protocol_policy = "redirect-to-https"
    cache_policy_id        = data.aws_cloudfront_cache_policy.caching_optimized.id
  }

  restrictions {
    geo_restriction {
      locations        = ["PL", "FR"]
      restriction_type = "whitelist"
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.cert.arn
    ssl_support_method  = "sni-only"
  }
}
