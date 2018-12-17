variable "dcos_install_mode" {
  description = "specifies which type of command to execute. Options: install or upgrade"
  default     = "install"
}

data "http" "whatismyip" {
  url = "http://whatismyip.akamai.com/"
}

module "dcos" {
  #source  = "dcos-terraform/dcos/azurerm"
  source  = "git::https://github.com/dcos-terraform/terraform-azurerm-dcos?ref=dynam-masters-poc"
  version = "~> 0.1"

  cluster_name        = "dcos-test${random_string.dcos_cluster_name.result}"
  ssh_public_key_file = "~/.ssh/id_rsa.pub"
  admin_ips           = ["${data.http.whatismyip.body}/32"]
  location            = "West US"

  num_masters        = "3"
  num_private_agents = "1"
  num_public_agents  = "1"

  tags = {
    owner      = "soak-infra-team"
    expiration = "4h"
  }

  dcos_version = "1.12.0"

  dcos_variant              = "ee"
  dcos_license_key_contents = "${file("./license.txt")}"

  dcos_install_mode = "${var.dcos_install_mode}"

  #DC/OS Config values that must be set
  dcos_exhibitor_storage_backend    = "azure"
  dcos_exhibitor_azure_account_name = "dcosexhibitor"
  dcos_exhibitor_azure_account_key  = "${module.dcos.azurem_storage_key}"
  dcos_exhibitor_azure_prefix       = "exhibitor"
  dcos_master_discovery             = "master_http_loadbalancer"
  dcos_exhibitor_address            = "${module.dcos.masters-internal-loadbalancer}"
  dcos_num_masters                  = "3"
}

# This is a current work around to an issue with CloudCleaner. A new Cluster name must be created each time.
resource "random_string" "dcos_cluster_name" {
  length  = 6
  special = false
  upper   = false
}

output "masters-ips" {
  value = "${module.dcos.masters-ips}"
}

output "cluster-address" {
  value = "${module.dcos.masters-loadbalancer}"
}

output "public-agents-loadbalancer" {
  value = "${module.dcos.public-agents-loadbalancer}"
}
