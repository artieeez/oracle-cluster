# Grant Object Storage service principal permission to manage lifecycle policies.
# Required IAM policy: https://docs.oracle.com/en-us/iaas/Content/Object/Tasks/usinglifecyclepolicies.htm
resource "oci_identity_policy" "object_storage_lifecycle" {
  provider = oci.home

  compartment_id = var.tenancy_ocid
  name           = "${var.cluster_name}-object-storage-lifecycle"
  description    = "Allow Object Storage service to manage lifecycle policies on buckets."
  statements = [
    "Allow service objectstorage-${var.region} to manage object-family in compartment id ${var.tenancy_ocid}"
  ]
}

resource "oci_objectstorage_bucket" "postgres_backups" {
  compartment_id = var.tenancy_ocid
  namespace      = data.oci_objectstorage_namespace.this.namespace
  name           = var.backup_bucket_name
  storage_tier   = "Archive"
  access_type    = "NoPublicAccess"
}

# IAM policy propagation is not instantaneous — sleep to avoid race condition.
resource "time_sleep" "policy_propagation" {
  depends_on      = [oci_identity_policy.object_storage_lifecycle]
  create_duration = "15s"
}

resource "oci_objectstorage_object_lifecycle_policy" "postgres_backups" {
  depends_on = [time_sleep.policy_propagation]

  namespace = data.oci_objectstorage_namespace.this.namespace
  bucket    = oci_objectstorage_bucket.postgres_backups.name

  rules {
    name       = "delete-old-backups"
    action     = "DELETE"
    is_enabled = true

    time_amount = var.backup_retention_days
    time_unit   = "DAYS"
  }
}
