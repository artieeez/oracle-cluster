terraform {
  backend "oci" {
    bucket              = "oke-cluster-tfstate"
    namespace           = "axtvnrdemzo7"
    key                 = "terraform.tfstate"
    region              = "sa-vinhedo-1"
    config_file_profile = "DEFAULT"
  }
}
