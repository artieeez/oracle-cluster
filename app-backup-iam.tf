# Least-privilege identity for the per-app backup CronJobs (artr-gitops
# apps/app-backups). They authenticate through the S3-compatible API with a
# Customer Secret Key, which inherits every Object Storage permission of its
# user, so the key must not belong to an administrator.
#
# The group can only list and create objects in the app-backups bucket: no
# read-back of other buckets, no overwrite, no delete. Old backups are expired
# by the bucket's lifecycle rule, not by the writer, so a leaked key cannot
# wipe the backups.
#
# The Customer Secret Key itself is created out of band (see
# docs/app-backups.md) so its secret never lands in Terraform state.
resource "oci_identity_user" "app_backup_writer" {
  provider = oci.home

  compartment_id = var.tenancy_ocid
  name           = "${var.cluster_name}-app-backup-writer"
  description    = "Service user for cluster per-app backup CronJobs (S3 API, append-only)."
}

resource "oci_identity_group" "app_backup_writers" {
  provider = oci.home

  compartment_id = var.tenancy_ocid
  name           = "${var.cluster_name}-app-backup-writers"
  description    = "Append-only writers for the ${var.app_backup_bucket_name} bucket."
}

resource "oci_identity_user_group_membership" "app_backup_writer" {
  provider = oci.home

  user_id  = oci_identity_user.app_backup_writer.id
  group_id = oci_identity_group.app_backup_writers.id
}

resource "oci_identity_policy" "app_backup_writers" {
  provider = oci.home

  compartment_id = var.tenancy_ocid
  name           = "${var.cluster_name}-app-backup-writers"
  description    = "Append-only access to ${var.app_backup_bucket_name} for the backup CronJobs."
  statements = [
    "Allow group ${oci_identity_group.app_backup_writers.name} to read buckets in tenancy where target.bucket.name = '${var.app_backup_bucket_name}'",
    "Allow group ${oci_identity_group.app_backup_writers.name} to manage objects in tenancy where all { target.bucket.name = '${var.app_backup_bucket_name}', any { request.permission = 'OBJECT_CREATE', request.permission = 'OBJECT_INSPECT' } }",
  ]
}

output "app_backup_writer_user_id" {
  description = "OCID of the append-only backup user; create its Customer Secret Key out of band."
  value       = oci_identity_user.app_backup_writer.id
}
