# OCI Customer Secret Keys — ops notes

Used for the Object Storage **S3-compatible** API only (the native `oci` Terraform backend does **not** use them). Limit: **2 per user**.

## Current state (2026-08-11)

| Key | Status |
|---|---|
| `sitio-rails-sqlite-backup` | Active — used by cluster `s3-credentials` secrets |
| `terraform-state-backend` | Active but **UNUSED** (created for the abandoned s3 backend; safe to delete) |
| `postgres-backup-sitio-production` | **Deleted** 2026-08-11 to free a quota slot — rotate anything that used it |

## Cleanup

Delete the unused key to free the quota slot:

```
oci iam customer-secret-key delete \
  --user-id "$(grep '^user' ~/.oci/config | cut -d= -f2)" \
  --customer-secret-key-id "<id from: oci iam customer-secret-key list>"
```

## Leftovers

- `~/.aws/credentials` has an `oci-tfstate` profile from the abandoned s3 backend — harmless, can be removed.
- Access keys are **shown once at creation**; retrieve the access key later via Console (Profile → Customer secret keys) but never the secret.
