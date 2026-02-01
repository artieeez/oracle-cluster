locals {
  policy_scope = var.iam_tenancy_name == "tenancy" ? "tenancy" : "compartment ${var.iam_tenancy_name}"
}

resource "oci_identity_policy" "bastion_access" {
  provider       = oci.home
  name           = "bastion-access"
  description    = "Allow bastion and bastion session management."
  compartment_id = var.tenancy_ocid

  statements = [
    "Allow group ${var.iam_admin_group_name} to manage bastion in ${local.policy_scope}",
    "Allow group ${var.iam_admin_group_name} to manage bastion-session in ${local.policy_scope}",
    "Allow group ${var.iam_admin_group_name} to use bastion in ${local.policy_scope}",
    "Allow group ${var.iam_admin_group_name} to use bastion-session in ${local.policy_scope}",
    "Allow group ${var.iam_admin_group_name} to read vcn in ${local.policy_scope}",
    "Allow group ${var.iam_admin_group_name} to read subnet in ${local.policy_scope}",
    "Allow group ${var.iam_admin_group_name} to read cluster-family in ${local.policy_scope}",
  ]
}
