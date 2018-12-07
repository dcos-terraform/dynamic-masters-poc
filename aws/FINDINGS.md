# Findings 
The Goal is to create a cluster that consists of "replaceable" Master nodes. This should require minimal effort from the user perspective. Eliminating (tainting) a master node should simply re-create/add a new master node to the DC/OS cluster with a simple `terraform apply` etc. This should include all necessary pre-reqs and installation of the Master role. 

Currently in order to successfully replace a master node and have your Terraform state in a 'up-to-date' state, it requires the following steps:

1) Taint the Master Instance Resource and the OS pre-reqs for the same Master Node. We must separate the OS pre-reqs and the Master installation. 

```
terraform taint -module dcos.dcos-infrastructure.dcos-master-instances.dcos-master-instances aws_instance.instance.0
terraform taint -module dcos.dcos-infrastructure.dcos-master-instances.dcos-master-instances null_resource.instance-prereq.0
```

2) Re-create the tainted resources.

```
terraform plan -out plan.out 
terraform apply plan.out
```

3) Taint the master3 null_resource to re-install the master role on the newly created instance. **NOTE: This will also try to re-create ALL underlying Agent null_resources as well. It will fail on the Agents which is expected and will be fixed in the next step.**

Also, to note here, this at times appears to be inconsistent on the correct null_resource for the master installation. Sometimes master2 and others master1. This caused pain.

```
terraform taint -module dcos.dcos-install.dcos-masters-install null_resource.master3
```

4) Apply changes again.
```
terraform plan -out plan.out 
terraform apply plan.out
```

5) Untaint ALL Agent null_resources from recent apply failures. *This is not viable for large clusters. Example is for a 3 Node Cluster (2 Private and 1 Public)*
```
terraform untaint -module dcos.dcos-install.dcos-public-agents-install null_resource.public-agents
terraform untaint -module dcos.dcos-install.dcos-private-agents-install null_resource.private-agents.1
terraform untaint -module dcos.dcos-install.dcos-private-agents-install null_resource.private-agents.0
```

5) Ensure that the new Master joins the cluster via DC/OS UI etc.... 

## Conclusion
As seen above, in our current setup with the dcos-install layer, it is not simple and is not user friendly. Due to the requirements needed for supporting intalling and upgrading clusters, it requires a multi-step approach and much attention from the user. It takes incredible amount of work to not only replace a master but to also fix the state of Terraform which is dangerous.

In our current setup, for the DC/OS Install layer, we install each Master one at a time and then install ALL the agents together at one time. From a Terraform perspective, in order to support installing each Master Node one at a time one after another and then install the agents directly after, we had to create triggers for each null_resource based on the dependencies of completion of earlier null_resources. 

Example:
```
resource "null_resource" "master2" {
  triggers = {
    dependency_id = "${null_resource.master1.id}"
  }
``` 

So when we taint null_resource.master1 for example, it sets off a chain reaction and triggers all underlying dependencies (master2 -> master3 -> Agents). Note this example is for 3 Masters. There would be more for clusters with more Master nodes. 

This is an unfortunate scenario resulting from using the bash style approach. We are currently limited on how we can support ALL types of install methods (Cluster Install, Cluster Upgrades, Node Replacements and whatever else may come up). 


## Possible Options to resolve

- Make our install scripts "smarter". If cluster is installed, skip the install process all togther. 
- Modify the way we currently handle DC/OS installation or add an additional method to support master node replacement.
- Use a different install method such as a config management tool to support this. 

# Scenarios Tested
### Taint a Master
```
terraform taint -module dcos.dcos-infrastructure.dcos-master-instances.dcos-master-instances aws_instance.instance.0
```

##### Does the following:
Re-create Master, Reads the Bootstrap, Modfies instances on the LB

```
Terraform will perform the following actions:

-/+ module.dcos.module.dcos-infrastructure.module.dcos-master-instances.module.dcos-master-instances.aws_instance.instance[0] (tainted) (new resource required)
      id:                                        "i-0583eedf4cda38302" => <computed> (forces new resource)
      ami:                                       "ami-9887c6e7" => "ami-9887c6e7"
      arn:                                       "arn:aws:ec2:us-east-1:575584959047:instance/i-0583eedf4cda38302" => <computed>
      associate_public_ip_address:               "true" => "true"
      availability_zone:                         "us-east-1a" => <computed>
      cpu_core_count:                            "2" => <computed>
      cpu_threads_per_core:                      "2" => <computed>
      ebs_block_device.#:                        "0" => <computed>
      ephemeral_block_device.#:                  "0" => <computed>
      get_password_data:                         "false" => "false"
      iam_instance_profile:                      "dcos-dcos-example-master_instance_profile" => "dcos-dcos-example-master_instance_profile"
      instance_state:                            "running" => <computed>
      instance_type:                             "m4.xlarge" => "m4.xlarge"
      ipv6_address_count:                        "" => <computed>
      ipv6_addresses.#:                          "0" => <computed>
      key_name:                                  "dcos-example-deployer-key" => "dcos-example-deployer-key"
      network_interface.#:                       "0" => <computed>
      network_interface_id:                      "eni-0eb639e48044a7a43" => <computed>
      password_data:                             "" => <computed>
      placement_group:                           "" => <computed>
      primary_network_interface_id:              "eni-0eb639e48044a7a43" => <computed>
      private_dns:                               "ip-172-12-3-8.ec2.internal" => <computed>
      private_ip:                                "172.12.3.8" => <computed>
      public_dns:                                "ec2-34-201-6-247.compute-1.amazonaws.com" => <computed>
      public_ip:                                 "34.201.6.247" => <computed>
      root_block_device.#:                       "1" => "1"
      root_block_device.0.delete_on_termination: "true" => "true"
      root_block_device.0.volume_id:             "vol-071fd380f1769ce75" => <computed>
      root_block_device.0.volume_size:           "120" => "120"
      root_block_device.0.volume_type:           "gp2" => "gp2"
      security_groups.#:                         "0" => <computed>
      source_dest_check:                         "true" => "true"
      subnet_id:                                 "subnet-0cd611a2f3808216f" => "subnet-0cd611a2f3808216f"
      tags.%:                                    "3" => "3"
      tags.Cluster:                              "dcos-example" => "dcos-example"
      tags.KubernetesCluster:                    "dcos-example" => "dcos-example"
      tags.Name:                                 "dcos-example-master1-" => "dcos-example-master1-"
      tenancy:                                   "default" => <computed>
      volume_tags.%:                             "0" => <computed>
      vpc_security_group_ids.#:                  "2" => "2"
      vpc_security_group_ids.1248379102:         "sg-01941ddf01ed8d5a9" => "sg-01941ddf01ed8d5a9"
      vpc_security_group_ids.53148349:           "sg-09582a5528117fde9" => "sg-09582a5528117fde9"

 <= module.dcos.module.dcos-install.module.dcos-bootstrap-install.module.dcos-bootstrap.data.template_file.script
      id:                                        <computed>
      rendered:                                  <computed>
      template:                                  "#!/bin/sh\n\nmkdir -p genconf\ncat << 'EOF' | sed '/^$/d' | tee genconf/config.yaml\n---\n# Auto-generated by Terraform Templates\n# Created on date: ${timestamp()}\n${bootstrap_private_ip == \"\" ? \"\" : \"bootstrap_url: http://${bootstrap_private_ip}:${dcos_bootstrap_port}\"}\n${dcos_cluster_name == \"\" ? \"\" : \"cluster_name: ${dcos_cluster_name}\"}\n${dcos_security== \"\" ? \"\" : \"security: ${dcos_security}\"}\n${dcos_resolvers== \"\" ? \"\" : \"resolvers: ${dcos_resolvers}\"}\n${dcos_oauth_enabled== \"\" ? \"\" : \"oauth_enabled: ${dcos_oauth_enabled}\"}\n${dcos_master_discovery== \"\" ? \"\" : \"master_discovery: ${dcos_master_discovery}\"}\n${dcos_aws_template_storage_bucket== \"\" ? \"\" : \"aws_template_storage_bucket: ${dcos_aws_template_storage_bucket}\"}\n${dcos_aws_template_storage_bucket_path== \"\" ? \"\" : \"aws_template_storage_bucket_path: ${dcos_aws_template_storage_bucket_path}\"}\n${dcos_aws_template_storage_region_name== \"\" ? \"\" : \"aws_template_storage_region_name: ${dcos_aws_template_storage_region_name}\"}\n${dcos_aws_template_upload== \"\" ? \"\" : \"aws_template_upload: ${dcos_aws_template_upload}\"}\n${dcos_aws_template_storage_access_key_id== \"\" ? \"\" : \"aws_template_storage_access_key_id: ${dcos_aws_template_storage_access_key_id}\"}\n${dcos_aws_template_storage_secret_access_key== \"\" ? \"\" : \"aws_template_storage_secret_access_key: ${dcos_aws_template_storage_secret_access_key}\"}\n${dcos_adminrouter_tls_1_0_enabled== \"\" ? \"\" : \"adminrouter_tls_1_0_enabled: ${dcos_adminrouter_tls_1_0_enabled}\"}\n${dcos_adminrouter_tls_1_1_enabled== \"\" ? \"\" : \"adminrouter_tls_1_1_enabled: ${dcos_adminrouter_tls_1_1_enabled}\"}\n${dcos_adminrouter_tls_1_2_enabled== \"\" ? \"\" : \"adminrouter_tls_1_2_enabled: ${dcos_adminrouter_tls_1_2_enabled}\"}\n${dcos_adminrouter_tls_cipher_suite== \"\" ? \"\" : \"adminrouter_tls_cipher_suite: ${dcos_adminrouter_tls_cipher_suite}\"}\n${dcos_ca_certificate_path== \"\" ? \"\" : \"ca_certificate_path: ${dcos_ca_certificate_path}\"}\n${dcos_ca_certificate_key_path== \"\" ? \"\" : \"ca_certificate_key_path: ${dcos_ca_certificate_key_path}\"}\n${dcos_ca_certificate_chain_path== \"\" ? \"\" : \"ca_certificate_chain_path: ${dcos_ca_certificate_chain_path}\"}\n${dcos_exhibitor_storage_backend== \"\" ? \"\" : \"exhibitor_storage_backend: ${dcos_exhibitor_storage_backend}\"}\n${dcos_exhibitor_storage_backend == \"zookeeper\" ? dcos_exhibitor_zk_hosts== \"\" ? \"\" : \"exhibitor_zk_hosts: ${dcos_exhibitor_zk_hosts}\" : \"\"}\n${dcos_exhibitor_storage_backend == \"zookeeper\" ? dcos_exhibitor_zk_path== \"\" ? \"\" : \"exhibitor_zk_path: ${dcos_exhibitor_zk_path}\" : \"\"}\n${dcos_exhibitor_storage_backend == \"aws_s3\" ? dcos_aws_access_key_id== \"\"? \"\" : \"aws_access_key_id: ${dcos_aws_access_key_id}\" : \"\"}\n${dcos_exhibitor_storage_backend == \"aws_s3\" ? dcos_aws_region== \"\" ? \"\" : \"aws_region: ${dcos_aws_region}\" : \"\"}\n${dcos_exhibitor_storage_backend == \"aws_s3\" ? dcos_aws_secret_access_key== \"\" ? \"\" : \"aws_secret_access_key: ${dcos_aws_secret_access_key}\" : \"\"}\n${dcos_exhibitor_storage_backend == \"aws_s3\" ? dcos_exhibitor_explicit_keys== \"\" ? \"\" : \"exhibitor_explicit_keys: ${dcos_exhibitor_explicit_keys}\" :\"\"}\n${dcos_exhibitor_storage_backend == \"aws_s3\" ? dcos_s3_bucket== \"\" ? \"\" : \"s3_bucket: ${dcos_s3_bucket}\" : \"\"}\n${dcos_exhibitor_storage_backend == \"aws_s3\" ? dcos_s3_prefix== \"\" ? \"\" : \"s3_prefix: ${dcos_s3_prefix}\" : \"\"}\n${dcos_exhibitor_storage_backend == \"azure\" ? dcos_exhibitor_azure_account_name== \"\" ? \"\" : \"exhibitor_azure_account_name: ${dcos_exhibitor_azure_account_name}\" : \"\"}\n${dcos_exhibitor_storage_backend == \"azure\" ? dcos_exhibitor_azure_account_key== \"\" ? \"\" : \"exhibitor_azure_account_key: ${dcos_exhibitor_azure_account_key}\" : \"\"}\n${dcos_exhibitor_storage_backend == \"azure\" ? dcos_exhibitor_azure_prefix== \"\" ? \"\" : \"exhibitor_azure_prefix: ${dcos_exhibitor_azure_prefix}\" : \"\"}\n${dcos_master_external_loadbalancer == \"\" ? \"\" : \"master_external_loadbalancer: ${dcos_master_external_loadbalancer}\"}\n${dcos_master_discovery == \"master_http_loadbalancer\" ? dcos_num_masters == \"\" ? \"\" : \"num_masters: ${dcos_num_masters}\" : \"\"}\n${dcos_master_discovery == \"master_http_loadbalancer\" ? dcos_exhibitor_address== \"\" ? \"\" : \"exhibitor_address: ${dcos_exhibitor_address}\" : \"\"}\n${dcos_master_discovery == \"static\" ? dcos_master_list== \"\" ? \"\" : \"master_list: ${dcos_master_list}\" : \"\"}\n${dcos_customer_key== \"\" ? \"\" : \"customer_key: ${dcos_customer_key}\"}\n${dcos_custom_checks== \"\" ? \"\" : \"custom_checks: ${dcos_custom_checks}\"}\n${dcos_dns_bind_ip_blacklist== \"\" ? \"\" :\"dns_bind_ip_blacklist: ${dcos_dns_bind_ip_blacklist}\"}\n${dcos_l4lb_enable_ipv6== \"\" ? \"\" : \"dcos_l4lb_enable_ipv6: ${dcos_l4lb_enable_ipv6}\"}\n${dcos_ucr_default_bridge_subnet== \"\" ? \"\" : \"dcos_ucr_default_bridge_subnet: ${dcos_ucr_default_bridge_subnet}\"}\n${dcos_enable_gpu_isolation== \"\" ? \"\" : \"enable_gpu_isolation: ${dcos_enable_gpu_isolation}\"}\n${dcos_gpus_are_scarce== \"\" ? \"\" : \"gpus_are_scarce: ${dcos_gpus_are_scarce}\"}\n${dcos_rexray_config_method== \"\" ? \"\" : \"rexray_config_method: ${dcos_rexray_config_method}\"}\n${dcos_rexray_config_filename== \"\" ? \"\" : \"rexray_config_filename: ${dcos_rexray_config_filename}\"}\n${dcos_auth_cookie_secure_flag== \"\" ? \"\" : \"auth_cookie_secure_flag: ${dcos_auth_cookie_secure_flag}\"}\n${dcos_bouncer_expiration_auth_token_days== \"\" ? \"\" : \"bouncer_expiration_auth_token_days: ${dcos_bouncer_expiration_auth_token_days}\"}\n${dcos_superuser_password_hash== \"\" ? \"\" : \"superuser_password_hash: ${dcos_superuser_password_hash}\"}\n${dcos_superuser_username== \"\" ? \"\" : \"superuser_username: ${dcos_superuser_username}\"}\n${dcos_telemetry_enabled== \"\" ? \"\" : \"telemetry_enabled: ${dcos_telemetry_enabled}\"}\n${dcos_zk_super_credentials== \"\" ? \"\" : \"zk_super_credentials: ${dcos_zk_super_credentials}\"}\n${dcos_zk_master_credentials== \"\" ? \"\" : \"zk_master_credentials: ${dcos_zk_master_credentials}\"}\n${dcos_zk_agent_credentials== \"\" ? \"\" : \"zk_agent_credentials: ${dcos_zk_agent_credentials}\"}\n${dcos_overlay_enable== \"\" ? \"\" : \"dcos_overlay_enable: ${dcos_overlay_enable}\"}\n${dcos_overlay_config_attempts== \"\" ? \"\" : \"dcos_overlay_config_attempts: ${dcos_overlay_config_attempts}\"}\n${dcos_overlay_mtu== \"\" ? \"\" : \"dcos_overlay_mtu: ${dcos_overlay_mtu}\"}\n${dcos_overlay_network== \"\" ? \"\" : \"dcos_overlay_network: ${dcos_overlay_network}\"}\n${dcos_dns_search== \"\" ? \"\" : \"dns_search: ${dcos_dns_search}\"}\n${dcos_dns_forward_zones== \"\" ? \"\" :\"dns_forward_zones: ${dcos_dns_forward_zones}\"}\n${dcos_master_dns_bindall== \"\" ? \"\" : \"master_dns_bindall: ${dcos_master_dns_bindall}\"}\n${dcos_mesos_max_completed_tasks_per_framework== \"\" ? \"\" : \"mesos_max_completed_tasks_per_framework: ${dcos_mesos_max_completed_tasks_per_framework}\"}\n${dcos_mesos_container_log_sink== \"\" ? \"\" : \"mesos_container_log_sink: ${dcos_mesos_container_log_sink}\"}\n${dcos_mesos_dns_set_truncate_bit== \"\" ? \"\" : \"mesos_dns_set_truncate_bit: ${dcos_mesos_dns_set_truncate_bit}\"}\n${dcos_master_dns_bindall== \"\" ? \"\" : \"master_dns_bindall: ${dcos_master_dns_bindall}\"}\n${dcos_license_key_contents== \"\" ? \"\" : \"license_key_contents: ${dcos_license_key_contents}\"}\n${dcos_fault_domain_detect_contents== \"\" ? \"\" : \"fault_domain_detect_contents: ${dcos_fault_domain_detect_contents}\"}\n${dcos_fault_domain_enabled== \"\" ? \"\" : \"fault_domain_enabled: ${dcos_fault_domain_enabled}\"}\n${dcos_use_proxy== \"\" ? \"\" : \"use_proxy: ${dcos_use_proxy}\"}\n${dcos_http_proxy== \"\" ? \"\" : \"http_proxy: ${dcos_http_proxy}\"}\n${dcos_https_proxy== \"\" ? \"\" : \"https_proxy: ${dcos_https_proxy}\"}\n${dcos_no_proxy== \"\" ? \"\" : \"no_proxy: ${dcos_no_proxy}\"}\n${dcos_check_time== \"\" ? \"\" : \"check_time: ${dcos_check_time}\"}\n${dcos_ip_detect_contents== \"\" ? \"\" : \"ip_detect_contents: ${dcos_ip_detect_contents}\"}\n${dcos_ip_detect_public_contents== \"\" ? \"\" : \"ip_detect_public_contents: ${dcos_ip_detect_public_contents}\"}\n${dcos_ip_detect_public_filename== \"\" ? \"\" : \"ip_detect_public_filename: ${dcos_ip_detect_public_filename}\"}\n${dcos_docker_remove_delay== \"\" ? \"\" : \"docker_remove_delay: ${dcos_docker_remove_delay}\"}\n${dcos_enable_docker_gc== \"\" ? \"\" : \"enable_docker_gc: ${dcos_enable_docker_gc}\"}\n${dcos_audit_logging== \"\" ? \"\" : \"audit_logging: ${dcos_audit_logging}\"}\n${dcos_gc_delay== \"\" ? \"\" : \"gc_delay: ${dcos_gc_delay}\"}\n${dcos_log_directory== \"\" ? \"\" : \"log_directory: ${dcos_log_directory}\"}\n${dcos_process_timeout== \"\" ? \"\" : \"process_timeout: ${dcos_process_timeout}\"}\n${dcos_cluster_docker_credentials== \"\" ? \"\" : \"cluster_docker_credentials: ${dcos_cluster_docker_credentials}\"}\n${dcos_cluster_docker_credentials_dcos_owned== \"\" ? \"\" : \"cluster_docker_credentials_dcos_owned: ${dcos_cluster_docker_credentials_dcos_owned}\"}\n${dcos_cluster_docker_credentials_write_to_etc== \"\" ? \"\" : \"cluster_docker_credentials_write_to_etc: ${dcos_cluster_docker_credentials_write_to_etc}\"}\n${dcos_cluster_docker_credentials_enabled== \"\" ? \"\" : \"cluster_docker_credentials_enabled: ${dcos_cluster_docker_credentials_enabled}\"}\n${dcos_cluster_docker_registry_url == \"\" ? \"\" : \"cluster_docker_registry_url: ${dcos_cluster_docker_registry_url}\"}\n${dcos_cluster_docker_registry_enabled == \"\" ? \"\" : \"cluster_docker_registry_enabled: ${dcos_cluster_docker_registry_enabled}\"}\n${dcos_rexray_config == \"\" ? \"\" : \"rexray_config: ${dcos_rexray_config}\"}\n${dcos_staged_package_storage_uri == \"\" ? \"\" : dcos_package_storage_uri == \"\" ? \"\" : \"cosmos_config:\"}\n${dcos_staged_package_storage_uri == \"\" ? \"\" : \"  staged_package_storage_uri: ${dcos_staged_package_storage_uri}\"}\n${dcos_package_storage_uri == \"\" ? \"\" : \"  package_storage_uri: ${dcos_package_storage_uri}\"}\n${dcos_config== \"\" ? \"\" : \"${dcos_config}\"}\nEOF\nfor i in {1..5}; do curl -o dcos_generate_config.${dcos_version}.sh ${dcos_download_path} && break || sleep 15; done\ncp /tmp/ip-detect genconf/. &> /dev/null; if [[ $? -ne 0 ]]; then echo \"skipping absent /tmp/ip-detect file\"; else echo \"copied file /tmp/ip-detect to ~/genconf\"; fi\ncp /tmp/ip-detect-public genconf/. &> /dev/null; if [[ $? -ne 0 ]]; then echo \"skipping absent /tmp/ip-detect-public file\"; else echo \"copied file /tmp/ip-detect-public to ~/genconf\"; fi\ncp /tmp/fault-domain-detect genconf/. &> /dev/null; if [[ $? -ne 0 ]]; then echo \"skipping absent /tmp/fault-domain-detect file\"; else echo \"copied file /tmp/fault-domain-detect to ~/genconf\"; fi\ncp /tmp/license.txt genconf/. &> /dev/null; if [[ $? -ne 0 ]]; then echo \"skipping absent /tmp/license.txt file\"; else echo \"copied file /tmp/license.txt to ~/genconf\"; fi\nbash dcos_generate_config.${dcos_version}.sh || exit 1\ndocker rm -f $(docker ps -a -q -f ancestor=nginx:1.15.0) &> /dev/null;if [[ $? -eq 0 ]]; then echo \"reloaded nginx...\"; fi\ndocker run -d -p ${dcos_bootstrap_port}:80 -v $PWD/genconf/serve:/usr/share/nginx/html:ro nginx:1.15.0\n"
      vars.%:                                    <computed>

  ~ module.dcos.module.dcos-infrastructure.module.dcos-elb.module.dcos-elb-masters-internal.module.masters-internal.aws_elb.loadbalancer
      instances.#:                               "" => <computed>

  ~ module.dcos.module.dcos-infrastructure.module.dcos-elb.module.dcos-elb-masters.module.masters.aws_elb.loadbalancer
      instances.#:                               "" => <computed>


Plan: 1 to add, 2 to change, 1 to destroy.
```

This scenario simply destroys and re-creates a master instance. Neither OS pre-reqs or DC/OS Master installation happens here. 


### Taint Master Node and the Pre-reqs 
```
terraform taint -module dcos.dcos-infrastructure.dcos-master-instances.dcos-master-instances aws_instance.instance.0
terraform taint -module dcos.dcos-infrastructure.dcos-master-instances.dcos-master-instances null_resource.instance-prereq.0
```

##### Does the following:
Re-creates Master Node and re-installs the OS pre-reqs.

```Terraform will perform the following actions:

-/+ module.dcos.module.dcos-infrastructure.module.dcos-master-instances.module.dcos-master-instances.aws_instance.instance[0] (tainted) (new resource required)
      id:                                        "i-058e69eaf7287c7e5" => <computed> (forces new resource)
      ami:                                       "ami-9887c6e7" => "ami-9887c6e7"
      arn:                                       "arn:aws:ec2:us-east-1:575584959047:instance/i-058e69eaf7287c7e5" => <computed>
      associate_public_ip_address:               "true" => "true"
      availability_zone:                         "us-east-1a" => <computed>
      cpu_core_count:                            "2" => <computed>
      cpu_threads_per_core:                      "2" => <computed>
      ebs_block_device.#:                        "0" => <computed>
      ephemeral_block_device.#:                  "0" => <computed>
      get_password_data:                         "false" => "false"
      iam_instance_profile:                      "dcos-dcos-example-master_instance_profile" => "dcos-dcos-example-master_instance_profile"
      instance_state:                            "running" => <computed>
      instance_type:                             "m4.xlarge" => "m4.xlarge"
      ipv6_address_count:                        "" => <computed>
      ipv6_addresses.#:                          "0" => <computed>
      key_name:                                  "dcos-example-deployer-key" => "dcos-example-deployer-key"
      network_interface.#:                       "0" => <computed>
      network_interface_id:                      "eni-080571fe670a0137d" => <computed>
      password_data:                             "" => <computed>
      placement_group:                           "" => <computed>
      primary_network_interface_id:              "eni-080571fe670a0137d" => <computed>
      private_dns:                               "ip-172-12-8-125.ec2.internal" => <computed>
      private_ip:                                "172.12.8.125" => <computed>
      public_dns:                                "ec2-54-147-122-77.compute-1.amazonaws.com" => <computed>
      public_ip:                                 "54.147.122.77" => <computed>
      root_block_device.#:                       "1" => "1"
      root_block_device.0.delete_on_termination: "true" => "true"
      root_block_device.0.volume_id:             "vol-04711bca73e6a0cf2" => <computed>
      root_block_device.0.volume_size:           "120" => "120"
      root_block_device.0.volume_type:           "gp2" => "gp2"
      security_groups.#:                         "0" => <computed>
      source_dest_check:                         "true" => "true"
      subnet_id:                                 "subnet-0cd611a2f3808216f" => "subnet-0cd611a2f3808216f"
      tags.%:                                    "3" => "3"
      tags.Cluster:                              "dcos-example" => "dcos-example"
      tags.KubernetesCluster:                    "dcos-example" => "dcos-example"
      tags.Name:                                 "dcos-example-master1-" => "dcos-example-master1-"
      tenancy:                                   "default" => <computed>
      volume_tags.%:                             "0" => <computed>
      vpc_security_group_ids.#:                  "2" => "2"
      vpc_security_group_ids.1248379102:         "sg-01941ddf01ed8d5a9" => "sg-01941ddf01ed8d5a9"
      vpc_security_group_ids.53148349:           "sg-09582a5528117fde9" => "sg-09582a5528117fde9"

-/+ module.dcos.module.dcos-infrastructure.module.dcos-master-instances.module.dcos-master-instances.null_resource.instance-prereq[0] (tainted) (new resource required)
      id:                                        "4631025339365300782" => <computed> (forces new resource)
...

...

...

```

This scenario almost gets us there. We have successfully re-added the Master and installed all necessary OS stuff. We could simply fix this issue by requiring the instance ID as a trigger inside the null_resource for the instance module. So anytime the instance gets re-created, this null_resource will as well. 

https://github.com/dcos-terraform/terraform-aws-instance/blob/master/main.tf#L74

```
### NOT TESTED BUT something of this nature 

triggers {
    instance = "${aws_instance.agent.*.id[count.index]}"
  }
```


### Taint the Master Node, Pre-Reqs and the Master install.
```
terraform taint -module dcos.dcos-infrastructure.dcos-master-instances.dcos-master-instances aws_instance.instance.0
terraform taint -module dcos.dcos-infrastructure.dcos-master-instances.dcos-master-instances null_resource.instance-prereq.0
terraform taint -module dcos.dcos-install.dcos-masters-install null_resource.master3
```

##### Does the following:
Re-creates Master instance, Install OS Pre-reqs and attempts to install the DC/OS Master role on new master(s) as well as install DC/OS on ALL Private Agents.

There are 2 issues with this scenario:

1) DC/OS Install Fails on new Master because OS Pre-reqs are not yet met. This is not a hard issue to resolve but is currently an issue.

2) Terraform is attempting to re-install DC/OS on the Agent Nodes as well. This will fail because DC/OS already exists. 

