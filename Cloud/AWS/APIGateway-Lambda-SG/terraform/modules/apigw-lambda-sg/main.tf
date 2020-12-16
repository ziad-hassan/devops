#####################
# Creating a Policy #
#####################
resource "aws_iam_policy" "modsg_policy" {
  name        = "${var.Name}-policy"
  path        = "/"
  description = "a policy to allow lambda to modify a sg's ingress rule"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeSecurityGroups",
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:RevokeSecurityGroupIngress"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

###################
# Creating a Role #
###################
resource "aws_iam_role" "modsg_role" {
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
    description           = "Allow access to cloudwatch logs and sg"
    name                  = "${var.Name}-role"
    path                  = "/"
    tags                  = {}
}

#################################
# Attach The Policy to the Role #
#################################
resource "aws_iam_role_policy_attachment" "modsg-role-policy-attach" {
  role       = aws_iam_role.modsg_role.name
  policy_arn = aws_iam_policy.modsg_policy.arn
}

################################
# Creating The Lambda Function #
################################
resource "aws_lambda_function" "modsg_lambda" {
    function_name                  = "${var.Name}-Lambda"
    handler                        = "${var.Function_Name}.${var.Handler_Name}"
    memory_size                    = var.Memory
    package_type                   = "Zip"
    role                           = aws_iam_role.modsg_role.arn
    filename                       = var.Script_Location
    runtime                        = var.Runtime
    tags                           = {}
    timeout                        = var.Timeout
}

#######################
# Creating The API GW #
#######################
resource "aws_api_gateway_rest_api" "modsg_api" {
  depends_on = [
     aws_lambda_function.modsg_lambda
  ]
  name        = "${var.Name}-apigw"
  description = "api gateway to contact a lambda function"
  endpoint_configuration {
        types            = [
            "REGIONAL",
        ]
    }
}

#######################
# Creating a Resource #
#######################
resource "aws_api_gateway_resource" "modsg_api_resource" {
   rest_api_id = aws_api_gateway_rest_api.modsg_api.id
   parent_id   = aws_api_gateway_rest_api.modsg_api.root_resource_id
   path_part   = var.Name
}

#####################
# Creating a Method #
#####################
resource "aws_api_gateway_method" "modsg_api_method" {
   rest_api_id   = aws_api_gateway_rest_api.modsg_api.id
   resource_id   = aws_api_gateway_resource.modsg_api_resource.id
   http_method   = "GET"
   authorization = "NONE"
   api_key_required = true
}

###########################
# Creating an Integration #
###########################
resource "aws_api_gateway_integration" "modsg_api_lambda" {
   rest_api_id = aws_api_gateway_rest_api.modsg_api.id
   resource_id = aws_api_gateway_method.modsg_api_method.resource_id
   http_method = aws_api_gateway_method.modsg_api_method.http_method

   integration_http_method = "POST"
   type                    = "AWS_PROXY"
   uri                     = aws_lambda_function.modsg_lambda.invoke_arn
}

##############################
# Creating a Method Response #
##############################
resource "aws_api_gateway_method_response" "modsg_api_method_response_200" {
  rest_api_id = aws_api_gateway_rest_api.modsg_api.id
  resource_id = aws_api_gateway_resource.modsg_api_resource.id
  http_method = aws_api_gateway_method.modsg_api_method.http_method
  status_code = "200"
  response_models = {
         "application/json" = "Empty"
    }
}

####################################
# Creating an Integration Response #
####################################
resource "aws_api_gateway_integration_response" "modsg_api_integration_response" {
   depends_on = [
     aws_api_gateway_integration.modsg_api_lambda
  ]
   rest_api_id = aws_api_gateway_rest_api.modsg_api.id
   resource_id = aws_api_gateway_resource.modsg_api_resource.id
   http_method = aws_api_gateway_method.modsg_api_method.http_method
   status_code = aws_api_gateway_method_response.modsg_api_method_response_200.status_code

   response_templates = {
       "application/json" = ""
   } 
}

#########################
# Creating a Deployment #
#########################
resource "aws_api_gateway_deployment" "modsg_api_deploy" {
   depends_on = [
     aws_lambda_permission.modsg_api_lambda_perm,
     aws_api_gateway_integration_response.modsg_api_integration_response,
     aws_api_gateway_method_response.modsg_api_method_response_200
   ]
   rest_api_id   = aws_api_gateway_rest_api.modsg_api.id
}

####################
# Creating a Stage #
####################
resource "aws_api_gateway_stage" "modsg_api_deploy_stage" {
  stage_name    = var.Stage
  rest_api_id   = aws_api_gateway_rest_api.modsg_api.id
  deployment_id = aws_api_gateway_deployment.modsg_api_deploy.id
}

#######################################
# Allow API Gateways to Invoke Lambda #
#######################################
resource "aws_lambda_permission" "modsg_api_lambda_perm" {
   statement_id  = "AllowAPIGatewayInvoke"
   action        = "lambda:InvokeFunction"
   function_name = aws_lambda_function.modsg_lambda.function_name
   principal     = "apigateway.amazonaws.com"

   # The "/*/*" portion grants access from any method on any resource
   # within the API Gateway REST API.
   source_arn = "${aws_api_gateway_rest_api.modsg_api.execution_arn}/*/*"
}

##########################
# Creating a Usage Plan #
##########################
resource "aws_api_gateway_usage_plan" "modsg_api_usage_plan" {
  name         = "${var.Name}-usage-plan"
  description  = "${var.Name}-usage-plan"

  api_stages {
    api_id = aws_api_gateway_rest_api.modsg_api.id
    stage  = aws_api_gateway_stage.modsg_api_deploy_stage.stage_name
  }
}

#######################
# Creating an API Key #
#######################
resource "aws_api_gateway_api_key" "modsg_api_key" {
  name = "${var.Name}-key-1"
}

###################################
# Associate API Key to Usage Plan #
###################################
resource "aws_api_gateway_usage_plan_key" "modsg_api_key_plan" {
  key_id        = aws_api_gateway_api_key.modsg_api_key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.modsg_api_usage_plan.id
}