data "aws_caller_identity" "current" {}

locals { 
  issuer_url = "${var.vault_public_url}/v1/identity/oidc/secrets-sync"
  issuer     = trimprefix(local.issuer_url, "https://")
  audience   = local.issuer # recommended by the Vault docs: unique per issuer
}

# Vault: issuer used in the identity tokens. Must match the URL AWS validates against.
# Note: this is namespace wide and affects every identity token issued in this namespace.
resource "vault_identity_oidc" "this" {
  issuer = var.vault_public_url
}

# AWS: trust Vault as an OIDC identity provider
resource "aws_iam_openid_connect_provider" "vault" {
  url            = local.issuer_url
  client_id_list = [local.audience]
}

resource "aws_iam_role" "sync" {
  name = "vault-secrets-sync"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.vault.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = { "${local.issuer}:aud" = local.audience }
        # sub = secrets-sync:<namespace_path>:aws-sm:<destination>
        StringLike = { "${local.issuer}:sub" = "secrets-sync:*:aws-sm:${var.destination_name}" }
      }
    }]
  })
}

# Minimum Secrets Manager permissions, scoped to Vault's default name prefix (vault/...).
resource "aws_iam_role_policy" "sync" {
  name = "secrets-manager-sync"
  role = aws_iam_role.sync.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:Create*",
        "secretsmanager:Update*",
        "secretsmanager:Delete*",
        "secretsmanager:TagResource",
      ]
      Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:vault*"
    }]
  })
}

# IAM is eventually consistent; avoid AccessDenied on the first sync.
resource "time_sleep" "iam" {
  create_duration = "15s"
  depends_on      = [aws_iam_role_policy.sync]
}

# Vault: destination + associations
resource "vault_secrets_sync_aws_destination" "this" {
  name     = var.destination_name
  region   = var.aws_region
  role_arn = aws_iam_role.sync.arn

  identity_token_audience_wo         = local.audience
  identity_token_audience_wo_version = 1

  depends_on = [time_sleep.iam, vault_identity_oidc.this]
}

resource "vault_secrets_sync_association" "this" {
  for_each = { for a in concat(local.test_associations, var.associations) : "${a.mount}/${a.secret_name}" => a }

  name        = vault_secrets_sync_aws_destination.this.name
  type        = vault_secrets_sync_aws_destination.this.type
  mount       = each.value.mount
  secret_name = each.value.secret_name
}
