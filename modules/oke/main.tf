data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

data "oci_containerengine_cluster_option" "cluster_options" {
  cluster_option_id = "all"
}

data "oci_containerengine_node_pool_option" "node_pool_options" {
  node_pool_option_id = "all"
}

locals {
  available_k8s_versions = sort(data.oci_containerengine_cluster_option.cluster_options.kubernetes_versions)
  kubernetes_version     = var.kubernetes_version == "latest" ? local.available_k8s_versions[length(local.available_k8s_versions) - 1] : var.kubernetes_version
  arm_image_ids          = [for source in data.oci_containerengine_node_pool_option.node_pool_options.sources : source.image_id if can(regex("(arm|aarch64)", lower(source.source_name)))]
  node_pool_image_id     = length(local.arm_image_ids) > 0 ? local.arm_image_ids[0] : data.oci_containerengine_node_pool_option.node_pool_options.sources[0].image_id
}

resource "oci_core_network_security_group" "endpoint" {
  compartment_id = var.tenancy_ocid
  display_name   = "${var.cluster_name}-endpoint-nsg"
  vcn_id         = var.vcn_id
}

resource "oci_core_network_security_group" "nodes" {
  compartment_id = var.tenancy_ocid
  display_name   = "${var.cluster_name}-nodes-nsg"
  vcn_id         = var.vcn_id
}

resource "oci_core_network_security_group_security_rule" "endpoint_from_nodes" {
  network_security_group_id = oci_core_network_security_group.endpoint.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.private_subnet_cidr
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 6443
      max = 6443
    }
  }
}

resource "oci_core_network_security_group_security_rule" "endpoint_from_nodes_kube_proxy" {
  network_security_group_id = oci_core_network_security_group.endpoint.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = oci_core_network_security_group.nodes.id
  source_type               = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = 12250
      max = 12250
    }
  }
}

resource "oci_core_network_security_group_security_rule" "nodes_from_endpoint_kube_proxy" {
  network_security_group_id = oci_core_network_security_group.nodes.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = oci_core_network_security_group.endpoint.id
  source_type               = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = 12250
      max = 12250
    }
  }
}

resource "oci_core_network_security_group_security_rule" "endpoint_from_public" {
  for_each                  = toset(var.api_public_allowed_cidrs)
  network_security_group_id = oci_core_network_security_group.endpoint.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = each.value
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 6443
      max = 6443
    }
  }
}

resource "oci_core_network_security_group_security_rule" "endpoint_egress" {
  network_security_group_id = oci_core_network_security_group.endpoint.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
}

resource "oci_core_network_security_group_security_rule" "nodes_from_vcn" {
  network_security_group_id = oci_core_network_security_group.nodes.id
  direction                 = "INGRESS"
  protocol                  = "all"
  source                    = var.vcn_cidr
  source_type               = "CIDR_BLOCK"
}

resource "oci_core_network_security_group_security_rule" "nodes_from_public_subnet_nodeports" {
  network_security_group_id = oci_core_network_security_group.nodes.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 30000
      max = 32767
    }
  }
}

resource "oci_core_network_security_group_security_rule" "nodes_ssh" {
  for_each                  = toset(var.ssh_allowed_cidrs)
  network_security_group_id = oci_core_network_security_group.nodes.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = each.value
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}

resource "oci_core_network_security_group_security_rule" "nodes_egress" {
  network_security_group_id = oci_core_network_security_group.nodes.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
}

resource "oci_containerengine_cluster" "oke" {
  compartment_id     = var.tenancy_ocid
  kubernetes_version = local.kubernetes_version
  name               = var.cluster_name
  vcn_id             = var.vcn_id

  endpoint_config {
    is_public_ip_enabled = true
    subnet_id            = var.public_subnet_id
    nsg_ids              = [oci_core_network_security_group.endpoint.id]
  }

  options {
    service_lb_subnet_ids = [var.public_subnet_id]
  }
}

resource "oci_containerengine_node_pool" "oke" {
  cluster_id         = oci_containerengine_cluster.oke.id
  compartment_id     = var.tenancy_ocid
  kubernetes_version = local.kubernetes_version
  name               = "${var.cluster_name}-pool"
  node_shape         = "VM.Standard.A1.Flex"
  ssh_public_key     = file(var.ssh_public_key_path)

  node_shape_config {
    ocpus         = 2
    memory_in_gbs = 12
  }

  node_source_details {
    image_id    = local.node_pool_image_id
    source_type = "IMAGE"
  }

  node_config_details {
    size    = var.node_pool_size
    nsg_ids = [oci_core_network_security_group.nodes.id]

    dynamic "placement_configs" {
      for_each = data.oci_identity_availability_domains.ads.availability_domains
      content {
        availability_domain = placement_configs.value.name
        subnet_id           = var.private_subnet_id
      }
    }
  }
}
