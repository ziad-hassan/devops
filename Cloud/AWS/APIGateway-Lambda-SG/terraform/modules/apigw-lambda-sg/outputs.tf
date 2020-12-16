output "API-Gateway-URL" { value = "${aws_api_gateway_stage.modsg_api_deploy_stage.invoke_url}/${var.Name}" }
output "API-Key" { value = aws_api_gateway_api_key.modsg_api_key.value }
