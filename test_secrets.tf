# Test data: a KV v2 mount with two secrets, synced automatically.
# Set create_test_secrets = false to remove them (this also deletes them from Secrets Manager).

variable "create_test_secrets" {
  description = "Create a KV v2 mount with test secrets and sync them."
  type        = bool
  default     = true
}

resource "vault_mount" "test" {
  count       = var.create_test_secrets ? 1 : 0
  path        = "kv-sync-test"
  type        = "kv"
  options     = { version = "2" }
  description = "Test secrets for secrets sync"
}

resource "vault_kv_secret_v2" "db" {
  count = var.create_test_secrets ? 1 : 0
  mount = vault_mount.test[0].path
  name  = "app1/database"
  data_json = jsonencode({
    username = "app1_user"
    password = "test-password-123"
    host     = "db.example.internal"
  })
}

resource "vault_kv_secret_v2" "api" {
  count = var.create_test_secrets ? 1 : 0
  mount = vault_mount.test[0].path
  name  = "app1/api-key"
  data_json = jsonencode({
    api_key = "test-api-key-abc"
  })
}

locals {
  test_associations = var.create_test_secrets ? [
    { mount = vault_mount.test[0].path, secret_name = vault_kv_secret_v2.db[0].name },
    { mount = vault_mount.test[0].path, secret_name = vault_kv_secret_v2.api[0].name },
  ] : []
}
