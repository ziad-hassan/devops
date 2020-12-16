terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
  access_key = "XXXXX"
  secret_key = "XXXXX"
}

module "apigw-lambda-sg" {
  source = "./modules/apigw-lambda-sg"
  Name = "modsg"
  Stage = "prod"
  Function_Name = "lambda_function"
  Handler_Name = "lambda_handler"
  Script_Location = "./lambda_function.zip"
  Runtime = "python2.7"
  Timeout = 15
  Memory = 128
}
