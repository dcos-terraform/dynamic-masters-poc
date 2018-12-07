data "http" "whatismyip" {
  url = "http://whatismyip.akamai.com/"
}

variable "dcos_install_mode" {
  description = "specifies which type of command to execute. Options: install or upgrade"
  default     = "install"
}

module "dcos" {
  #source = "dcos-terraform/dcos/aws"
  source              = "git::https://github.com/dcos-terraform/terraform-aws-dcos?ref=dynam-masters-poc"
  ssh_public_key_file = "~/.ssh/id_rsa.pub"
  admin_ips           = ["${data.http.whatismyip.body}/32"]
  num_masters         = "3"
  num_private_agents  = "2"
  num_public_agents   = "1"

  dcos_variant              = "ee"
  dcos_version              = "1.12.0"
  dcos_license_key_contents = "${file("./license.txt")}"
  dcos_install_mode         = "${var.dcos_install_mode}"

  #DC/OS Config values that must be set
  dcos_exhibitor_explicit_keys   = "false"
  dcos_exhibitor_storage_backend = "aws_s3"
  dcos_s3_prefix                 = "exhibitor"
  dcos_s3_bucket                 = "ext-exhibitor-test"
  dcos_aws_region                = "us-east-1" #per aws_region: Must set aws_region, no way to calculate value.
  dcos_master_discovery         = "master_http_loadbalancer"
  dcos_exhibitor_address        = "${module.dcos.masters-internal-loadbalancer}"
  dcos_num_masters               = "3"
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
