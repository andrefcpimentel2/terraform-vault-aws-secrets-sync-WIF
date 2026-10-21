# Vault secrets sync to AWS Secrets Manager with WIF (minimal)

This is the minimum setup for a self managed Vault Enterprise 2.0+ cluster. Vault never stores AWS keys. It signs a JWT, and AWS STS exchanges that JWT for temporary credentials on the role.

## Creates

- `identity/oidc/config` issuer set to `vault_public_url`
- IAM OIDC provider for `<vault_public_url>/v1[/<ns>]/identity/oidc/secrets-sync`
- IAM role `vault-secrets-sync`, with a trust policy that checks `aud` and `sub`, and Secrets Manager access to `secret:vault*`
- Vault secrets sync destination (WIF) and one association per entry in `associations`
- Test data (`test_secrets.tf`, on by default): KV v2 mount `kv-sync-test` with `app1/database` and `app1/api-key`, both synced. Turn it off with `create_test_secrets = false`. That also deletes the test secrets from Secrets Manager.

To check in AWS after apply, open Secrets Manager in the console and filter by the tag key `hashicorp:vault`. You should see `vault/kv_<accessor>/app1/database` and `vault/kv_<accessor>/app1/api-key`.

## Prerequisites

1. Vault Enterprise 2.0+ with secrets sync activated (do this once):
   `vault write -f sys/activation-flags/secrets-sync/activate`
2. AWS STS must be able to reach these two URLs from the internet over HTTPS, with a publicly trusted certificate:
   - `<issuer_url>/.well-known/openid-configuration`
   - `<issuer_url>/.well-known/keys`

   Running Vault on AWS does not get around this, because STS does not call into your VPC. If Vault is private, use a public ALB with an ACM certificate and listener rules that forward only those two paths to Vault, and return 403 for everything else.
3. The Vault token has rights on `identity/oidc/config` and `sys/sync/*` in the namespace (plus `sys/mounts/kv-sync-test` and `kv-sync-test/*` for the test secrets).

## Run

```bash
export VAULT_ADDR=https://vault.internal.example.com:8200
export VAULT_TOKEN=...
cp terraform.tfvars.example terraform.tfvars   # edit
curl -s https://vault.example.com/v1/identity/oidc/secrets-sync/.well-known/openid-configuration
terraform init && terraform apply
vault read sys/sync/destinations/aws-sm/aws-sm/associations   # expect SYNCED
```

## Notes

- Setting the issuer applies to the whole namespace. If other identity tokens or plugin WIF setups rely on the default issuer (`api_addr`), check them.
- Vault's default secret names look like `vault/kv_<accessor>/<path>`. That's why the IAM policy is scoped to `secret:vault*`. If you change the naming template, change the policy to match.
- The `sub` condition uses a wildcard for the namespace part. After the first sync you can pin it to the exact value shown in CloudTrail (`AssumeRoleWithWebIdentity`).
