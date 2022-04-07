############################################
#######     Create a lambda role     #######
############################################

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

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

#################################################
#######     Create a policy for lambda    #######
#################################################

resource "aws_iam_role_policy" "lambda-policy" {
  name = "lambda-test"
  role = "${aws_iam_role.iam_for_lambda.id}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:Get*",
                "s3:List*",
                "s3-object-lambda:Get*",
                "s3-object-lambda:List*",
                "s3-object-lambda:Get*",
                "s3-object-lambda:List*",
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "ec2:CreateNetworkInterface",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DeleteNetworkInterface",
                "ec2:AssignPrivateIpAddresses",
                "ec2:UnassignPrivateIpAddresses"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

###############################################
#######     Create a lambda function    #######
###############################################

resource "aws_lambda_function" "proceed_s3_file_to_rds" {
  filename      = "${local.lambda_zip_location}"
  function_name = "proceed_s3_file_to_rds"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "lambda.lambda_handler"
  runtime = "python3.8"
  layers = [aws_lambda_layer_version.lambda_layer.arn]

  vpc_config {
    subnet_ids         = [for subnet in aws_subnet.private_subnets : subnet.id]
    security_group_ids = [aws_default_security_group.lambda.id]
  }

  tags = {
    Group	= "InterviewAssessments"
    ResourceStatus= "Temporary"
  }
}

locals {
  lambda_zip_location = "outputs/lambda.zip"
}

data "archive_file" "test" {
  type        = "zip"
  source_file = "lambda.py"
  output_path = "${local.lambda_zip_location}"
}

############################################
#######     Create a lambda layer    #######
############################################

resource "aws_lambda_layer_version" "lambda_layer" {
  filename   = "layer.zip"
  layer_name = "lambda_layer_name"

  compatible_runtimes = ["python3.8"]
}

##############################################
#######     Create a lambda invoke     #######
##############################################

resource "aws_lambda_permission" "test" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.proceed_s3_file_to_rds.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${aws_s3_bucket.test-lambda-terziev.id}"
}
