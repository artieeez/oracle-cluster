provider "oci" {
  region              = var.region
  config_file_profile = var.oci_profile
}

provider "oci" {
  alias               = "home"
  region              = var.home_region
  config_file_profile = var.oci_profile
}

module "network" {
  source              = "./modules/network"
  tenancy_ocid        = var.tenancy_ocid
  cluster_name        = var.cluster_name
  vcn_cidr            = var.vcn_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  api_public_allowed_cidrs = var.api_public_allowed_cidrs
}

module "oke" {
  source              = "./modules/oke"
  tenancy_ocid        = var.tenancy_ocid
  cluster_name        = var.cluster_name
  kubernetes_version  = var.kubernetes_version
  ssh_public_key_path = var.ssh_public_key_path
  node_pool_size      = var.node_pool_size
  vcn_id              = module.network.vcn_id
  vcn_cidr            = var.vcn_cidr
  public_subnet_id    = module.network.public_subnet_id
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_id   = module.network.private_subnet_id
  private_subnet_cidr = var.private_subnet_cidr
  api_public_allowed_cidrs = var.api_public_allowed_cidrs
  ssh_allowed_cidrs   = var.ssh_allowed_cidrs
}
