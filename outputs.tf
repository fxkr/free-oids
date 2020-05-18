output "base_url_deployment" {
  value = "${aws_api_gateway_deployment.free_oids_deployment.invoke_url}"
}

output "base_url_api_gw" {
  value = "${aws_api_gateway_domain_name.free_oids.cloudfront_domain_name}"
}

output "production_url" {
  value = "https://${var.dns_name}.${var.dns_domain}/"
}
