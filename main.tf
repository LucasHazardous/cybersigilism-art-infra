data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  project_region                  = "eu-west-3"
  project_tag                     = "cybersigilism-art"
  domain_name                     = "cybersigilism.art"
  website_bucket_name             = "cybersigilism-art-website"
  codebuild_name                  = "cybersigilism-art-website"
  codebuild_cloudwatch_group_name = "cybersigilism-art-website"
  budget_lambda_name = "budget-killswitch"
}
