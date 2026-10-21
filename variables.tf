variable "aws_region" {
  description = "Region where secrets are written in AWS Secrets Manager."
  type        = string
  default     = "eu-west-2"
}



variable "vault_public_url" {
  description = "Public HTTPS base URL (publicly trusted cert) where AWS STS can reach Vault's OIDC discovery endpoints, e.g. https://vault.example.com. No trailing slash."
  type        = string

  validation {
    condition     = startswith(var.vault_public_url, "https://")
    error_message = "vault_public_url must start with https://."
  }
}

variable "destination_name" {
  description = "Name of the secrets sync destination."
  type        = string
  default     = "aws-sm"
}

variable "associations" {
  description = "Vault secrets to sync. mount = KV v2 mount, secret_name = path inside the mount."
  type = list(object({
    mount       = string
    secret_name = string
  }))
  default = []
}
