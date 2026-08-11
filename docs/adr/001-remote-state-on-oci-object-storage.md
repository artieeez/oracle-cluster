# ADR 001: Remote state on OCI Object Storage

Status: Accepted · 2026-08-11

## Context

State was stored locally (`terraform.tfstate` in the repo dir). We wanted it remote, versioned, encrypted, and with locking so a lost machine doesn't lose infrastructure.

## Decision

Use Terraform's native `oci` backend against the private, versioned `oke-cluster-tfstate` bucket (`backend.tf`). It authenticates with the same `~/.oci/config` profile as the provider and provides real state locking via `If-None-Match`.

## Why not the `s3`-compatible backend

The S3-compatible route was tried first and is a **dead end**:

- OCI's S3 gateway rejects AWS chunked-transfer-encoding PUTs (`NotImplemented: AWS chunked encoding not supported`), which modern AWS SDKs use by default for uploads.
- The S3 path also has no locking.

## Gotchas worth remembering

- A Customer Secret Key's `id` **is** its S3 access key, but newly created keys take ~3–5 minutes to propagate to the Object Storage S3 gateway — early auth failures are usually just propagation delay.
- Customer Secret Keys are limited to **2 per user** (see `docs/oci-keys.md`).
- An interrupted `terraform plan`/`apply` leaves a stale lock object in the bucket; clear it with `terraform force-unlock -force <lock-id>`.

## Maintenance hazard: CI can't read `terraform.tfvars`

`terraform.tfvars` is gitignored (contains secrets), so `.github/workflows/nightly-plan.yml` mirrors its values as hardcoded `TF_VAR_*` env vars. **Keep those in sync with `terraform.tfvars`** or the nightly plan will report false drift.
