# Weekly snapshots of the shared NFS block volume (oci_core_volume.db_volume).
#
# Nearly every nfs-client PVC in the cluster (pocketid, tinyauth, hermes, home,
# minecraft, sitio, monitoring) lives on this one volume, so a volume-level
# backup is the coarse safety net; per-app backups to Object Storage cover
# point restores.
#
# Sized to stay inside the Always Free allowance of 5 volume backups in total:
# one backup a week kept 27 days means the oldest expires the day before the
# next one is taken, so at most 4 backups exist at once.
resource "oci_core_volume_backup_policy" "db_volume_weekly" {
  compartment_id = var.tenancy_ocid
  display_name   = "${var.cluster_name}-db-volume-weekly"

  schedules {
    backup_type       = "INCREMENTAL"
    period            = "ONE_WEEK"
    day_of_week       = "SUNDAY"
    hour_of_day       = 7 # 04:00 BRT, clear of the 06:00 / 06:30 UTC sitio backup jobs
    offset_type       = "STRUCTURED"
    time_zone         = "UTC"
    retention_seconds = 27 * 24 * 60 * 60
  }
}

resource "oci_core_volume_backup_policy_assignment" "db_volume" {
  asset_id  = oci_core_volume.db_volume.id
  policy_id = oci_core_volume_backup_policy.db_volume_weekly.id
}
