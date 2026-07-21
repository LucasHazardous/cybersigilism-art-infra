resource "aws_budgets_budget" "max_spending" {
  name         = "$10 Budget"
  limit_amount = "10"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  budget_type  = "COST"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 70
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.admin_email]
  }

  notification {
    threshold                 = 90
    comparison_operator       = "GREATER_THAN"
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.budget_killswitch.arn]
  }

  cost_filter {
    name   = "TagKeyValue"
    values = ["user:Project${"$"}${local.project_tag}"]
  }
}

resource "aws_sns_topic" "budget_killswitch" {
  name = "budget-killswitch-topic"
}

resource "aws_sns_topic_subscription" "budget_lambda" {
  topic_arn = aws_sns_topic.budget_killswitch.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.budget_killswitch.arn
}

data "archive_file" "budget_lambda" {
  type        = "zip"
  source_file = "${path.module}/budget_killswitch_lambda.py"
  output_path = "${path.module}/budget_killswitch_lambda.zip"
}

data "aws_iam_policy_document" "assume_budget_lambda" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "budget_lambda_cloudfront" {
  statement {
    effect = "Allow"
    actions = [
      "cloudfront:GetDistributionConfig",
      "cloudfront:UpdateDistribution"
    ]
    resources = [aws_cloudfront_distribution.s3_distribution.arn]
  }
}

resource "aws_iam_role_policy" "allow_cloudfront_in_lambda" {
  policy = data.aws_iam_policy_document.budget_lambda_cloudfront.json
  role   = aws_iam_role.budget_lambda_execution.id
}

resource "aws_iam_role" "budget_lambda_execution" {
  name               = "budget-lambda-execution"
  assume_role_policy = data.aws_iam_policy_document.assume_budget_lambda.json
}

resource "aws_lambda_function" "budget_killswitch" {
  filename      = data.archive_file.budget_lambda.output_path
  code_sha256   = data.archive_file.budget_lambda.output_sha256
  handler       = "budget_killswitch_lambda.lambda_handler"
  timeout       = 30
  function_name = "budget-killswitch"
  role          = aws_iam_role.budget_lambda_execution.arn
  runtime       = "python3.14"

  environment {
    variables = {
      CLOUDFRONT_DISTRIBUTION_ID = aws_cloudfront_distribution.s3_distribution.id
    }
  }
}

resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.budget_killswitch.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.budget_killswitch.arn
}

resource "aws_ce_cost_allocation_tag" "project" {
  tag_key = "Project"
  status  = "Active"
}
