resource "oci_bastion_bastion" "oke" {
  compartment_id               = var.tenancy_ocid
  bastion_type                 = "STANDARD"
  name                         = "${var.cluster_name}-bastion"
  target_subnet_id             = var.bastion_subnet_id
  client_cidr_block_allow_list = var.bastion_allowed_cidrs
}

resource "oci_bastion_session" "oke_k8s_api" {
  bastion_id = oci_bastion_bastion.oke.id

  key_details {
    public_key_content = file(var.bastion_ssh_public_key_path)
  }

  target_resource_details {
    session_type                       = "PORT_FORWARDING"
    target_resource_id                 = var.target_resource_id
    target_resource_private_ip_address = var.target_private_ip
    target_resource_port               = var.target_port
  }
}
