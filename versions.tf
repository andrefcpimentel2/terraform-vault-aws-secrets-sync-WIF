terraform {
  required_version = ">= 1.11.0" # write only attributes

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = ">= 5.8.0" # WIF fields on vault_secrets_sync_aws_destination
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.12.0"
    }
  }
}

# Credentials from the standard AWS chain.
provider "aws" {
  region = var.aws_region
}

# Address and token from VAULT_ADDR / VAULT_TOKEN.
provider "vault" {
  namespace = var.vault_namespace != "" ? var.vault_namespace : null
}
