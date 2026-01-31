provider "oci" {
  region              = var.region
  config_file_profile = var.oci_profile
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

data "oci_containerengine_cluster_option" "cluster_options" {
  cluster_option_id = "all"
}

data "oci_containerengine_node_pool_option" "node_pool_options" {
  node_pool_option_id = "all"
}

data "oci_core_services" "all" {
  filter {
    name   = "name"
    values = ["All.*Services In Oracle Services Network"]
    regex  = true
  }
}

locals {
  available_k8s_versions = sort(data.oci_containerengine_cluster_option.cluster_options.kubernetes_versions)
  kubernetes_version     = var.kubernetes_version == "latest" ? local.available_k8s_versions[length(local.available_k8s_versions) - 1] : var.kubernetes_version
  arm_image_ids          = [for source in data.oci_containerengine_node_pool_option.node_pool_options.sources : source.image_id if can(regex("(arm|aarch64)", lower(source.source_name)))]
  node_pool_image_id     = length(local.arm_image_ids) > 0 ? local.arm_image_ids[0] : data.oci_containerengine_node_pool_option.node_pool_options.sources[0].image_id
}

resource "oci_core_vcn" "oke" {
  cidr_block     = var.vcn_cidr
  compartment_id = var.tenancy_ocid
  display_name   = "${var.cluster_name}-vcn"
  dns_label      = "okevcn"
}

resource "oci_core_security_list" "public_api" {
  compartment_id = var.tenancy_ocid
  display_name   = "${var.cluster_name}-public-api-sl"
  vcn_id         = oci_core_vcn.oke.id

  egress_security_rules {
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    protocol         = "all"
  }

  ingress_security_rules {
    protocol    = "6"
    source      = var.vcn_cidr
    source_type = "CIDR_BLOCK"

    tcp_options {
      min = 6443
      max = 6443
    }
  }
}

resource "oci_core_internet_gateway" "oke" {
  compartment_id = var.tenancy_ocid
  display_name   = "${var.cluster_name}-igw"
  vcn_id         = oci_core_vcn.oke.id
  enabled        = true
}

resource "oci_core_nat_gateway" "oke" {
  compartment_id = var.tenancy_ocid
  display_name   = "${var.cluster_name}-nat"
  vcn_id         = oci_core_vcn.oke.id
}

resource "oci_core_service_gateway" "oke" {
  compartment_id = var.tenancy_ocid
  display_name   = "${var.cluster_name}-sgw"
  vcn_id         = oci_core_vcn.oke.id

  services {
    service_id = data.oci_core_services.all.services[0].id
  }
}

resource "oci_core_route_table" "public" {
  compartment_id = var.tenancy_ocid
  display_name   = "${var.cluster_name}-public-rt"
  vcn_id         = oci_core_vcn.oke.id

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.oke.id
  }
}

resource "oci_core_route_table" "private" {
  compartment_id = var.tenancy_ocid
  display_name   = "${var.cluster_name}-private-rt"
  vcn_id         = oci_core_vcn.oke.id

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.oke.id
  }

  route_rules {
    destination       = data.oci_core_services.all.services[0].cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.oke.id
  }
}

resource "oci_core_subnet" "public" {
  cidr_block                 = var.public_subnet_cidr
  compartment_id             = var.tenancy_ocid
  display_name               = "${var.cluster_name}-public-subnet"
  dns_label                  = "public"
  prohibit_public_ip_on_vnic = false
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_vcn.oke.default_security_list_id, oci_core_security_list.public_api.id]
  vcn_id                     = oci_core_vcn.oke.id
}

resource "oci_core_subnet" "private" {
  cidr_block                 = var.private_subnet_cidr
  compartment_id             = var.tenancy_ocid
  display_name               = "${var.cluster_name}-private-subnet"
  dns_label                  = "private"
  prohibit_public_ip_on_vnic = true
  route_table_id             = oci_core_route_table.private.id
  vcn_id                     = oci_core_vcn.oke.id
}

resource "oci_core_network_security_group" "endpoint" {
  compartment_id = var.tenancy_ocid
  display_name   = "${var.cluster_name}-endpoint-nsg"
  vcn_id         = oci_core_vcn.oke.id
}

resource "oci_core_network_security_group" "nodes" {
  compartment_id = var.tenancy_ocid
  display_name   = "${var.cluster_name}-nodes-nsg"
  vcn_id         = oci_core_vcn.oke.id
}

resource "oci_core_network_security_group_security_rule" "endpoint_from_vcn" {
  network_security_group_id = oci_core_network_security_group.endpoint.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.vcn_cidr
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 6443
      max = 6443
    }
  }
}

resource "oci_core_network_security_group_security_rule" "endpoint_from_allowed" {
  for_each                  = toset(var.api_allowed_cidrs)
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
  vcn_id             = oci_core_vcn.oke.id

  endpoint_config {
    is_public_ip_enabled = true
    subnet_id            = oci_core_subnet.public.id
    nsg_ids              = [oci_core_network_security_group.endpoint.id]
  }

  options {
    service_lb_subnet_ids = [oci_core_subnet.public.id]
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
    memory_in_gbs = 6
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
        subnet_id           = oci_core_subnet.private.id
      }
    }
  }
}
