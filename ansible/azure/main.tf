# Find Public IP
data "http" "whatismyip" {
  url = "http://whatismyip.akamai.com/"
}

# Begin Variables 
variable "bootstrap_image" {
  description = "[BOOTSTRAP] Image to be used"
  type        = "map"
  default     = {
    publisher = "OpenLogic"
    offer     = "CentOS"
    sku       = "7.5.20180815"
    version   = "7.5"
  }
}

variable "masters_image" {
  description = "[MASTERS] Image to be used"
  type        = "map"
  default     = {
    publisher = "OpenLogic"
    offer     = "CentOS"
    sku       = "7.5.20180815"
    version   = "7.5"
  }
}

variable "private_agents_image" {
  description = "[PRIVATE AGENTS] Image to be used"
  type        = "map"
  default     = {
    publisher = "OpenLogic"
    offer     = "CentOS"
    sku       = "7.5.20180815"
    version   = "7.5"
  }
}

variable "public_agents_image" {
  description = "[PUBLIC AGENTS] Image to be used"
  type        = "map"
  default     = {
    publisher = "OpenLogic"
    offer     = "CentOS"
    sku       = "7.5.20180815"
    version   = "7.5"
  }
}

variable "cluster_name" {
  description = "Name of your DC/OS Cluster"
  default     = "dcos-ansible"
}

variable "num_masters" {
  description = "Number of Masters"
  default     = "3"
}

variable "num_private_agents" {
  description = "Number of Private Agents"
  default     = "1"
}

variable "num_public_agents" {
  description = "Number of Public Agents"
  default     = "1"
}

variable "ssh_public_key_file" {
  description = "SSH Key Location"
  default     = "~/.ssh/id_rsa.pub"
}

variable "azure_storage_account_name" {
  description = "Storage Account Name External Exhibitor"
  default = "dcosexhibitor"
}

resource "random_string" "dcos_cluster_name" {
  length  = 6
  special = false
  upper   = false
}

# Begin Modules
module "dcos-infrastructure" {
  source                      = "git::https://github.com/dcos-terraform/terraform-azurerm-infrastructure?ref=dynam-masters-poc"
  admin_ips                   = ["${data.http.whatismyip.body}/32"]
  bootstrap_image             = "${var.bootstrap_image}"
  masters_image               = "${var.masters_image}"
  private_agents_image        = "${var.private_agents_image}"
  public_agents_image         = "${var.public_agents_image}"
  cluster_name                = "${var.cluster_name}${random_string.dcos_cluster_name.result}"
  num_masters                 = "${var.num_masters}"
  num_private_agents          = "${var.num_private_agents}"
  num_public_agents           = "${var.num_public_agents}"
  ssh_public_key_file         = "${var.ssh_public_key_file}"
  azurem_storage_account_name = "${var.azure_storage_account_name}"
  location                    = "West US"

  tags = {
    owner      = "soak-infra-team"
    expiration = "4h"
  }

}

module "dcos-ansible-bridge" {
  #source               = "dcos-terraform/dcos-ansible-bridge/localfile"
  source               = "git::https://github.com/dcos-terraform/terraform-localfile-dcos-ansible-bridge?ref=dynam-masters-poc"
  bootstrap_ip         = "${module.dcos-infrastructure.bootstrap.public_ip}"
  master_ips           = ["${module.dcos-infrastructure.masters.public_ips}"]
  private_agent_ips    = ["${module.dcos-infrastructure.private_agents.public_ips}"]
  public_agent_ips     = ["${module.dcos-infrastructure.public_agents.public_ips}"]
  bootstrap_private_ip = "${module.dcos-infrastructure.bootstrap.private_ip}"
  master_private_ips   = ["${module.dcos-infrastructure.masters.private_ips}"]
  dcos_cluster_name    = "Testing-Cluster"
  
   # Testing Dynamic Masters Ansible 
  dcos_exhibitor_storage_backend    = "azure"
  dcos_exhibitor_azure_account_name = "${var.azure_storage_account_name}"
  dcos_exhibitor_azure_account_key  = "${module.dcos-infrastructure.azurem_storage_key}"
  dcos_exhibitor_azure_prefix       = "exhibitor"
  dcos_master_discovery             = "master_http_loadbalancer"
  dcos_exhibitor_address            = "${module.dcos-infrastructure.lb.masters-internal}"
  dcos_num_masters                  = "3"
  dcos_license_key_contents         = "${file("./license.txt")}"
  
}

# Begin Outputs
output "bootstraps" {
  description = "bootsrap IPs"
  value       = "${join("\n", flatten(list(module.dcos-infrastructure.bootstrap.public_ip)))}"
}

output "bootstrap_private_ip" {
  description = "bootsrap IPs"
  value       = "${module.dcos-infrastructure.bootstrap.private_ip}"
}

output "masters" {
  description = "masters IPs"
  value       = "${join("\n", flatten(list(module.dcos-infrastructure.masters.public_ips)))}"
}

output "masters_private_ips" {
  description = "List of private IPs for Masters (for DCOS config)"
  value       = "${join("\n", flatten(list(module.dcos-infrastructure.masters.private_ips)))}"
}

output "private_agents" {
  description = "Private Agents IPs"
  value       = "${join("\n", flatten(list(module.dcos-infrastructure.private_agents.public_ips)))}"
}

output "public_agents" {
  description = "Public Agents IPs"
  value       = "${join("\n", flatten(list(module.dcos-infrastructure.public_agents.public_ips)))}"
}

