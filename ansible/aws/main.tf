# Find Public IP
data "http" "whatismyip" {
  url = "http://whatismyip.akamai.com/"
}

# Begin Variables 
variable "aws_ami" {
  description = "AMI to use"
  default     = "ami-4bf3d731"
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

variable "aws_s3_bucket" {
  description = "Bucket for External Exhibitor"
  default = "ext-exhibitor-test"
}



# Begin Modules
module "dcos-infrastructure" {
  source              = "git::https://github.com/dcos-terraform/terraform-aws-infrastructure?ref=dynam-masters-poc"
  admin_ips           = ["${data.http.whatismyip.body}/32"]
  aws_ami             = "${var.aws_ami}"
  cluster_name        = "${var.cluster_name}"
  num_masters         = "${var.num_masters}"
  num_private_agents  = "${var.num_private_agents}"
  num_public_agents   = "${var.num_public_agents}"
  ssh_public_key_file = "${var.ssh_public_key_file}"
  aws_s3_bucket       = "${var.aws_s3_bucket}"

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
  dcos_exhibitor_explicit_keys    = "false"
  dcos_exhibitor_storage_backend  = "aws_s3"
  dcos_s3_prefix                  = "exhibitor"
  dcos_s3_bucket                  = "${var.aws_s3_bucket}"
  dcos_aws_region                 = "us-east-1" #per aws_region: Must set aws_region, no way to calculate value.
  dcos_master_discovery           = "master_http_loadbalancer"
  dcos_exhibitor_address          = "${module.dcos-infrastructure.elb.masters_internal_dns_name}"
  dcos_num_masters                = "3"
  dcos_license_key_contents       = "${file("./license.txt")}"
  
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

output "cluster-url" {
  description = "DC/OS UI URL"
  value       = "${module.dcos-infrastructure.elb.masters_dns_name}"
}
