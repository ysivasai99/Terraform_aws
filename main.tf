provider "aws" {
  region = "us-east-1"
}

resource "aws_iam_role" "lambda_execution_role" {
  name               = "lambda_execution_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_cloudwatch_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "slack_notification_function" {
  filename         = "function.zip" # Pre-packaged zip file containing the Lambda function code
  function_name    = "slack_notification_function"
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = filebase64sha256("function.zip")
  environment {
    variables = {
      SLACK_WEBHOOK_URL = "https://hooks.slack.com/services/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"
    }
  }
}

resource "aws_cloudwatch_event_rule" "deployment_status_rule" {
  name        = "deployment_status_rule"
  description = "Triggers when a deployment event occurs"
  event_pattern = <<EOF
{
  "source": ["aws.codepipeline"],
  "detail-type": ["CodePipeline Pipeline Execution State Change"]
}
EOF
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.deployment_status_rule.name
  target_id = "slack_notification_lambda"
  arn       = aws_lambda_function.slack_notification_function.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.slack_notification_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.deployment_status_rule.arn
}

output "lambda_function_arn" {
  value = aws_lambda_function.slack_notification_function.arn
}
