resource "oci_ons_notification_topic" "cost_alerts" {
  provider = oci.home

  compartment_id = var.tenancy_ocid
  name           = "${var.cluster_name}-cost-alerts"
  description    = "Cost/budget alerts fan-out (Slack + email)."
}

resource "oci_ons_subscription" "cost_alerts_slack" {
  provider = oci.home

  compartment_id = var.tenancy_ocid
  topic_id       = oci_ons_notification_topic.cost_alerts.id
  protocol       = "CUSTOM_HTTPS"
  endpoint       = var.slack_webhook_url
}

resource "oci_ons_subscription" "cost_alerts_email" {
  provider = oci.home

  compartment_id = var.tenancy_ocid
  topic_id       = oci_ons_notification_topic.cost_alerts.id
  protocol       = "EMAIL"
  endpoint       = var.cost_alert_email
}

resource "oci_events_rule" "budget_triggered_alert_to_ons" {
  provider = oci.home

  compartment_id = var.tenancy_ocid
  display_name   = "${var.cluster_name}-budget-triggered-alert-to-ons"
  description    = "Forward budget triggered-alert events to Notifications (Slack + email)."
  is_enabled     = true

  condition = jsonencode({
    eventType = "com.oraclecloud.budgets.createtriggeredalert"
    data = {
      additionalDetails = {
        budgetId = oci_budget_budget.cost_tripwire.id
      }
    }
  })

  actions {
    actions {
      action_type = "ONS"
      is_enabled  = true
      topic_id    = oci_ons_notification_topic.cost_alerts.id
      description = "Send budget triggered alerts to ONS topic."
    }
  }
}

