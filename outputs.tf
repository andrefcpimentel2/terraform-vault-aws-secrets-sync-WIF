output "role_arn" {
  value = aws_iam_role.sync.arn
}

output "issuer_url" {
  value = local.issuer_url
}

output "discovery_url" {
  description = "Must be reachable from the internet (AWS STS fetches it)."
  value       = "${local.issuer_url}/.well-known/openid-configuration"
}
