# Dynamic Masters on AWS for DC/OS Terraform
All the things for AWS to enable and test ["Replaceable Master Nodes"](https://docs.mesosphere.com/1.12/administering-clusters/replacing-a-master-node/#master-discovery-master-http-loadbalancer) for DC/OS. This feature allows for users to store exhibitor backend on S3 and place Master nodes behind a LB in order to keep from having to use a static master list. 

The following repos require changes to be made in order to make this work and the work can be tracked on the `dynam-masters-poc` branch.

- [`terraform-aws-dcos`](https://github.com/dcos-terraform/terraform-aws-dcos/tree/dynam-masters-poc)

- [`terraform-aws-infrastructure`](https://github.com/dcos-terraform/terraform-aws-infrastructure/tree/dynam-masters-poc)

- [`terraform-aws-iam`](https://github.com/dcos-terraform/terraform-aws-iam/tree/dynam-masters-poc)


Please use the provided `main.tf` as a template for your deployment and note the following configs are required:

```
dcos_exhibitor_explicit_keys
dcos_exhibitor_storage_backend
dcos_s3_prefix                
dcos_s3_bucket                
dcos_aws_region               
dcos_master_discovery         
dcos_exhibitor_address        
dcos_num_masters              
```

Also see configuration reference for [`master_discovery`](https://docs.mesosphere.com/1.12/installing/production/advanced-configuration/configuration-reference/#master-discovery-required) and [`exhibitor_storage_backend`](https://docs.mesosphere.com/1.12/installing/production/advanced-configuration/configuration-reference/#exhibitor-storage-backend) for more details.

*On platforms like AWS where internal IPs are allocated dynamically, you should not use a static master list. If a master instance were to terminate for any reason, it could lead to cluster instability. It is recommended to use aws_s3 for the exhibitor storage backend since we can rely on s3 to manage quorum size when the master nodes are unavailable.


## Usage
Pull down the repo and make desire adjustments to `main.tf`.

```
eval $(maws li account)
export AWS_DEFAULT_REGION="us-east-1"
ssh-add ~/.ssh/id_rsa
terraform init 
terraform plan -out plan.out 
terraform apply plan.out
```

NOTE: This method takes a bit longer than normal to become available. Exhibitor and Mesos Masters will have to restart several times before they are ready. Typically takes an additional 5-6 minutes before UI is ready.

Taint the resources. (WORK IN PROGRESS)
```
terraform taint -module dcos.dcos-install.dcos-masters-install null_resource.master1
terraform taint -module dcos.dcos-infrastructure.dcos-master-instances.dcos-master-instances aws_instance.instance.0
```

Re-apply state.
```
terraform plan -out plan.out 
terraform apply plan.out
```

## Tested Versions (CentOS 7.5)
- 1.11.7 (successful)
- 1.12.0 (successful)