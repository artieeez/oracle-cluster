locals {
  cost_alert_thresholds = {
    "50pct"  = 0.50
    "80pct"  = 0.80
    "100pct" = 1.00
  }
}

resource "oci_budget_budget" "cost_tripwire" {
  provider = oci.home

  compartment_id = var.tenancy_ocid
  display_name   = "${var.cluster_name}-cost-tripwire"
  description    = "Low budget tripwire to detect accidental OCI spend."

  amount       = var.cost_budget_amount
  reset_period = "MONTHLY"

  target_type = "COMPARTMENT"
  targets     = [var.tenancy_ocid]
}

resource "oci_budget_alert_rule" "cost_tripwire_actual" {
  for_each = local.cost_alert_thresholds
  provider = oci.home

  budget_id      = oci_budget_budget.cost_tripwire.id
  display_name   = "${var.cluster_name}-cost-tripwire-actual-${each.key}"
  description    = "Alert when actual spend crosses $${each.value}."
  type           = "ACTUAL"
  threshold_type = "ABSOLUTE"
  threshold      = each.value
  recipients     = var.cost_alert_email
  message        = "OCI budget tripwire exceeded: actual spend is >= $${each.value} in this month."
}
