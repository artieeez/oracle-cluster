resource "oci_identity_dynamic_group" "oke_nodes" {
  provider = oci.home

  compartment_id = var.tenancy_ocid
  name           = "${var.cluster_name}-oke-nodes"
  description    = "Dynamic group for OKE worker instances to pull private images from OCIR."

  # OKE worker nodes are compute instances in this tenancy.
  matching_rule = "ALL {instance.compartment.id = '${var.tenancy_ocid}'}"
}

resource "oci_identity_policy" "oke_nodes_ocir_pull" {
  provider = oci.home

  compartment_id = var.tenancy_ocid
  name           = "${var.cluster_name}-oke-nodes-ocir-pull"
  description    = "Allow OKE worker nodes to pull private images from OCIR."

  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.oke_nodes.name} to read repos in tenancy",
  ]
}
