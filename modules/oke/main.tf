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
  # The NLB carries HTTP/HTTPS only. Pi-hole DNS (53/TCP, 53/UDP) and DoT (853)
  # are deliberately not published here: clients reach Pi-hole over the tailnet
  # (pihole-dns.<tailnet>.ts.net). See docs/adr/002-close-public-dns.md.
  traefik_node_ports = {
    web       = 32080
    websecure = 32443
  }
  # Games workloads ride the same NLB (reserved public IP, *.artr.com.br) through
  # dedicated TCP listeners instead of Traefik. Must match the Service nodePort in
  # artr-gitops apps/games/minecraft/service.yaml.
  minecraft_node_port = 30565
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

resource "oci_core_network_security_group" "traefik_nlb" {
  compartment_id = var.tenancy_ocid
  display_name   = "${var.cluster_name}-traefik-nlb-nsg"
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

resource "oci_core_network_security_group_security_rule" "nodes_from_public_subnet_nodeports_udp" {
  network_security_group_id = oci_core_network_security_group.nodes.id
  direction                 = "INGRESS"
  protocol                  = "17"
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"

  udp_options {
    destination_port_range {
      min = 30000
      max = 32767
    }
  }
}

resource "oci_core_network_security_group_security_rule" "traefik_nlb_http_ingress" {
  network_security_group_id = oci_core_network_security_group.traefik_nlb.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 80
      max = 80
    }
  }
}

resource "oci_core_network_security_group_security_rule" "traefik_nlb_https_ingress" {
  network_security_group_id = oci_core_network_security_group.traefik_nlb.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }
}

resource "oci_core_network_security_group_security_rule" "traefik_nlb_minecraft_ingress" {
  network_security_group_id = oci_core_network_security_group.traefik_nlb.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 25565
      max = 25565
    }
  }
}

resource "oci_core_network_security_group_security_rule" "traefik_nlb_egress" {
  network_security_group_id = oci_core_network_security_group.traefik_nlb.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
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
    image_id                = local.node_pool_image_id
    source_type             = "IMAGE"
    boot_volume_size_in_gbs = var.node_boot_volume_size_gbs
  }

  # The node image ships an LVM layout sized for the image, not for
  # boot_volume_size_in_gbs: sda3 stays at ~45.5 GiB inside a larger boot volume,
  # so the extra space is never allocated and "/" keeps filling up until kubelet
  # evicts pods on imagefs.available < 15%. The image does not grow the partition
  # and neither does OKE, so every replacement node starts with the gap again.
  #
  # user_data must be base64-encoded cloud-init and it *replaces* the image's
  # default user data, so the payload runs the OKE init script itself after the
  # growth step. See docs/adr/002-node-boot-partition-autogrow.md.
  node_metadata = {
    user_data = base64encode(file("${path.module}/files/node_boot_grow.sh"))
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

resource "oci_network_load_balancer_network_load_balancer" "traefik" {
  compartment_id             = var.tenancy_ocid
  display_name               = "${var.cluster_name}-traefik-nlb"
  subnet_id                  = var.public_subnet_id
  is_private                 = false
  network_security_group_ids = [oci_core_network_security_group.traefik_nlb.id]

  reserved_ips {
    id = var.reserved_public_ip_id
  }
}

resource "oci_network_load_balancer_backend_set" "traefik_http" {
  name                     = "traefik-http-backendset"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.traefik.id
  policy                   = "FIVE_TUPLE"

  health_checker {
    protocol = "TCP"
    port     = local.traefik_node_ports.web
  }

  depends_on = [oci_network_load_balancer_network_load_balancer.traefik]
}

resource "oci_network_load_balancer_backend_set" "traefik_https" {
  name                     = "traefik-https-backendset"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.traefik.id
  policy                   = "FIVE_TUPLE"

  health_checker {
    protocol = "TCP"
    port     = local.traefik_node_ports.websecure
  }

  depends_on = [oci_network_load_balancer_backend_set.traefik_http]
}

resource "oci_network_load_balancer_backend_set" "minecraft" {
  name                     = "minecraft-backendset"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.traefik.id
  policy                   = "FIVE_TUPLE"

  # NodePort accepts connections only once the minecraft pod is Ready, so a TCP
  # probe on the NodePort doubles as a real game-port health check.
  health_checker {
    protocol = "TCP"
    port     = local.minecraft_node_port
  }

  depends_on = [oci_network_load_balancer_backend_set.traefik_https]
}

resource "oci_network_load_balancer_backend" "traefik_http_nodes" {
  for_each                 = { for node in oci_containerengine_node_pool.oke.nodes : node.id => node.private_ip if node.private_ip != null && node.state != "DELETED" }
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.traefik.id
  backend_set_name         = oci_network_load_balancer_backend_set.traefik_http.name
  ip_address               = each.value
  port                     = local.traefik_node_ports.web
}

resource "oci_network_load_balancer_backend" "traefik_https_nodes" {
  for_each                 = { for node in oci_containerengine_node_pool.oke.nodes : node.id => node.private_ip if node.private_ip != null && node.state != "DELETED" }
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.traefik.id
  backend_set_name         = oci_network_load_balancer_backend_set.traefik_https.name
  ip_address               = each.value
  port                     = local.traefik_node_ports.websecure

  # OCI NLB allows only one backend mutation at a time.
  depends_on = [oci_network_load_balancer_backend.traefik_http_nodes]
}

resource "oci_network_load_balancer_backend" "minecraft_nodes" {
  for_each                 = { for node in oci_containerengine_node_pool.oke.nodes : node.id => node.private_ip if node.private_ip != null && node.state != "DELETED" }
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.traefik.id
  backend_set_name         = oci_network_load_balancer_backend_set.minecraft.name
  ip_address               = each.value
  port                     = local.minecraft_node_port

  depends_on = [oci_network_load_balancer_backend.traefik_https_nodes]
}

resource "oci_network_load_balancer_listener" "http" {
  name                     = "http-80"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.traefik.id
  default_backend_set_name = oci_network_load_balancer_backend_set.traefik_http.name
  port                     = 80
  protocol                 = "TCP"

  depends_on = [
    oci_network_load_balancer_backend_set.traefik_http,
    oci_network_load_balancer_backend_set.traefik_https,
    oci_network_load_balancer_backend_set.minecraft
  ]
}

resource "oci_network_load_balancer_listener" "https" {
  name                     = "https-443"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.traefik.id
  default_backend_set_name = oci_network_load_balancer_backend_set.traefik_https.name
  port                     = 443
  protocol                 = "TCP"

  depends_on = [
    oci_network_load_balancer_backend_set.traefik_http,
    oci_network_load_balancer_backend_set.traefik_https,
    oci_network_load_balancer_backend_set.minecraft
  ]
}

resource "oci_network_load_balancer_listener" "minecraft" {
  name                     = "minecraft-tcp-25565"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.traefik.id
  default_backend_set_name = oci_network_load_balancer_backend_set.minecraft.name
  port                     = 25565
  protocol                 = "TCP"

  depends_on = [
    oci_network_load_balancer_backend_set.traefik_http,
    oci_network_load_balancer_backend_set.traefik_https,
    oci_network_load_balancer_backend_set.minecraft
  ]
}
