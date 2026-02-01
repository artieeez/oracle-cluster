data "oci_core_services" "all" {
  filter {
    name   = "name"
    values = ["All.*Services In Oracle Services Network"]
    regex  = true
  }
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

  dynamic "ingress_security_rules" {
    for_each = toset(var.api_public_allowed_cidrs)
    content {
      protocol    = "6"
      source      = ingress_security_rules.value
      source_type = "CIDR_BLOCK"

      tcp_options {
        min = 6443
        max = 6443
      }
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
  security_list_ids          = [oci_core_vcn.oke.default_security_list_id]
  vcn_id                     = oci_core_vcn.oke.id
}

resource "oci_core_public_ip" "reserved" {
  compartment_id = var.tenancy_ocid
  display_name   = "${var.cluster_name}-traefik-reserved-ip"
  lifetime       = "RESERVED"
}
