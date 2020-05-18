provider "aws" {
  profile    = "default"
  region     = "us-west-1"
}

provider "aws" {
  profile    = "default"
  region     = "us-east-1"
  alias      = "us-east-1"
}


resource "aws_dynamodb_table" "free_oids_counter" {
  name           = "free-oids-counter"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "Prefix"

  attribute {
    name = "Prefix"
    type = "S"
  }

  tags = {
    Name    = "free-oids-counter"
    Project = "free-oids"
  }
}

resource "aws_dynamodb_table" "free_oids_log" {
  name           = "free-oids-log"
  billing_mode   = "PAY_PER_REQUEST"

  hash_key       = "Prefix"
  range_key      = "Id"

  attribute {
    name = "Prefix"
    type = "S"
  }

  attribute {
    name = "Id"
    type = "N"
  }

  tags = {
    Name    = "free-oids-log"
    Project = "free-oids"
  }
}

resource "aws_iam_role_policy" "free_oids_lambda" {
  name = "free-oids-lambda-iam-role-policy"
  role = "${aws_iam_role.free_oids_lambda_iam_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Scan",
          "dynamodb:Query",
          "dynamodb:UpdateItem"
      ],
      "Resource": [
        "${aws_dynamodb_table.free_oids_counter.arn}",
        "${aws_dynamodb_table.free_oids_log.arn}"
      ]
    }
  ]
}
EOF
}

resource aws_iam_role_policy_attachment basic {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = "${aws_iam_role.free_oids_lambda_iam_role.name}"
}

resource "aws_iam_role" "free_oids_lambda_iam_role" {
  name = "free-oids-lambda-iam-role"

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

data "archive_file" "free_oids_lambda_zip" {
  source_dir  = "${path.module}/lambda/"
  output_path = "${path.module}/lambda.zip"
  type        = "zip"
}

resource "aws_lambda_function" "free_oids_lambda" {
  function_name    = "free-oids-lambda"
  handler          = "handler.lambda_handler"
  role             = "${aws_iam_role.free_oids_lambda_iam_role.arn}"
  runtime          = "python3.7"
  timeout          = 60
  filename         = "${data.archive_file.free_oids_lambda_zip.output_path}"
  source_code_hash = "${data.archive_file.free_oids_lambda_zip.output_base64sha256}"

  environment {
    variables = {
      FREE_OIDS_PREFIX = var.oid_prefix
      FREE_OIDS_RECAPTCHA_SECRET = var.recaptcha_secret 
    }
  }
}



resource "aws_lambda_permission" "free_oids_lambda_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.free_oids_lambda.function_name}"
  principal     = "apigateway.amazonaws.com"
  source_arn = "${aws_api_gateway_rest_api.free_oids_api_gateway_api.execution_arn}/*/*"
}


resource "aws_api_gateway_rest_api" "free_oids_api_gateway_api" {
  name = "free-oids-api"
}

resource "aws_api_gateway_resource" "api_dir" {
  parent_id   = "${aws_api_gateway_rest_api.free_oids_api_gateway_api.root_resource_id}"
  rest_api_id = "${aws_api_gateway_rest_api.free_oids_api_gateway_api.id}"
  path_part   = "api"
}

resource "aws_api_gateway_resource" "free_oids_api_gateway_resource" {
  parent_id   = "${aws_api_gateway_resource.api_dir.id}"
  rest_api_id = "${aws_api_gateway_rest_api.free_oids_api_gateway_api.id}"
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "free_oids_api_gateway_method" {
  rest_api_id   = "${aws_api_gateway_rest_api.free_oids_api_gateway_api.id}"
  resource_id   = "${aws_api_gateway_resource.free_oids_api_gateway_resource.id}"
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "free_oids_integration" {
  rest_api_id             = "${aws_api_gateway_rest_api.free_oids_api_gateway_api.id}"
  resource_id             = "${aws_api_gateway_resource.free_oids_api_gateway_resource.id}"
  http_method             = "${aws_api_gateway_method.free_oids_api_gateway_method.http_method}"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.free_oids_lambda.invoke_arn}"
}

#resource "aws_api_gateway_integration" "free_oids_integration_root" {
#  rest_api_id = "${aws_api_gateway_rest_api.free_oids_api_gateway_api.id}"
#  resource_id = "${aws_api_gateway_method.free_oids_api_gateway_method_root.resource_id}"
#  http_method = "${aws_api_gateway_method.free_oids_api_gateway_method_root.http_method}"
#
#  integration_http_method = "POST"
#  type                    = "AWS_PROXY"
#  uri                     = "${aws_lambda_function.free_oids_lambda.invoke_arn}"
#}

resource "aws_api_gateway_deployment" "free_oids_deployment" {
  depends_on = [
    "aws_api_gateway_integration.free_oids_integration",
    #"aws_api_gateway_integration.free_oids_integration_root",
    "aws_api_gateway_integration.S3Integration"
  ]

  rest_api_id = "${aws_api_gateway_rest_api.free_oids_api_gateway_api.id}"
  stage_name  = "test"

  # Automated redeployment. Otherwise manual redeployment (e.g. via AWS console)
  # can be necessary on certain changes. Downside: More deployments than strictly necessary.
  # https://github.com/hashicorp/terraform/issues/6613
  stage_description = "${md5(file("main.tf"))}"

  # Avoids error "Active stages pointing to this deployment must be moved or deleted"
  # https://github.com/hashicorp/terraform/issues/10674#issuecomment-290767062
  lifecycle {
    create_before_destroy = true
  }
}





resource "aws_s3_bucket" "free_oids_s3_bucket" {
  acl    = "private"
}

resource "aws_s3_bucket_object" "free_oids_s3_bucket_object" {
  bucket = "${aws_s3_bucket.free_oids_s3_bucket.id}"
  key    = "index.html"
  source = "${path.module}/index.html"
  etag   = "${filemd5("${path.module}/index.html")}"
  content_type = "text/html"
}

resource "aws_api_gateway_domain_name" "free_oids" {
  domain_name              = "${var.dns_domain}"

  certificate_arn = "${aws_acm_certificate.cert.arn}"
}

resource "aws_route53_record" "free_oids" {
    zone_id = var.zone_id
    name    = ""
    type    = "A"
    alias {
        evaluate_target_health = true
        name                   = "${aws_api_gateway_domain_name.free_oids.cloudfront_domain_name}"
        zone_id                = "${aws_api_gateway_domain_name.free_oids.cloudfront_zone_id}"
    }
}

resource "aws_acm_certificate" "cert" {
  domain_name       = "${var.dns_domain}"
  validation_method = "DNS"

  # API Gateway custom domains can only use certs in us-east-1 currently
  provider = "aws.us-east-1"
}

resource "aws_route53_record" "cert_validation" {
  name    = "${aws_acm_certificate.cert.domain_validation_options.0.resource_record_name}"
  type    = "${aws_acm_certificate.cert.domain_validation_options.0.resource_record_type}"
  zone_id = var.zone_id
  records = ["${aws_acm_certificate.cert.domain_validation_options.0.resource_record_value}"]
  ttl     = 60
  provider = "aws.us-east-1"
}

resource "aws_api_gateway_base_path_mapping" "test" {
  api_id      = "${aws_api_gateway_rest_api.free_oids_api_gateway_api.id}"
  stage_name  = "${aws_api_gateway_deployment.free_oids_deployment.stage_name}"
  domain_name = "${aws_api_gateway_domain_name.free_oids.domain_name}"
}

resource "aws_iam_role" "free_oids_s3_execution_role" {
  name = "free-oids-s3-iam-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "apigateway.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# TODO dont allow s3:*
# TODO dont allow resource:*
resource "aws_iam_role_policy" "free_oids_s3" {
  name = "free-oids-s3-policy-role"
  role = "${aws_iam_role.free_oids_s3_execution_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
          "s3:*"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
EOF
}

# TODO remove
# "${aws_s3_bucket.free_oids_s3_bucket.arn}"

resource "aws_api_gateway_integration" "S3Integration" {
  rest_api_id = "${aws_api_gateway_rest_api.free_oids_api_gateway_api.id}"
  resource_id = "${aws_api_gateway_rest_api.free_oids_api_gateway_api.root_resource_id}"
  http_method = "${aws_api_gateway_method.GetBuckets.http_method}"

  # Needed because of https://github.com/hashicorp/terraform/issues/10501
  integration_http_method = "GET"

  type = "AWS"

  # See uri description: https://docs.aws.amazon.com/apigateway/api-reference/resource/integration/
  uri         = "arn:aws:apigateway:${aws_s3_bucket.free_oids_s3_bucket.region}:s3:path/${aws_s3_bucket.free_oids_s3_bucket.id}/index.html"
  credentials = "${aws_iam_role.free_oids_s3_execution_role.arn}"
}

resource "aws_api_gateway_method" "GetBuckets" {
  rest_api_id   = "${aws_api_gateway_rest_api.free_oids_api_gateway_api.id}"
  resource_id   = "${aws_api_gateway_rest_api.free_oids_api_gateway_api.root_resource_id}"
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "response_200" {
  rest_api_id = "${aws_api_gateway_rest_api.free_oids_api_gateway_api.id}"
  resource_id = "${aws_api_gateway_rest_api.free_oids_api_gateway_api.root_resource_id}"
  http_method = "${aws_api_gateway_method.GetBuckets.http_method}"
  status_code = "200"
  response_parameters = {
    "method.response.header.Content-Type" = true
    "method.response.header.Content-Length" = true
    "method.response.header.Timestamp" = true
  }
}

resource "aws_api_gateway_integration_response" "My200IntegrationResponse" {
  depends_on = ["aws_api_gateway_integration.S3Integration"]

  rest_api_id = "${aws_api_gateway_rest_api.free_oids_api_gateway_api.id}"
  resource_id = "${aws_api_gateway_rest_api.free_oids_api_gateway_api.root_resource_id}"
  http_method = "${aws_api_gateway_method.GetBuckets.http_method}"
  status_code = "${aws_api_gateway_method_response.response_200.status_code}"

  response_parameters = {
    "method.response.header.Timestamp"      = "integration.response.header.Date"
    "method.response.header.Content-Length" = "integration.response.header.Content-Length"
    "method.response.header.Content-Type"   = "integration.response.header.Content-Type"
  }
}
