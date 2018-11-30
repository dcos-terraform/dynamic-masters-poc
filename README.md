# PoC for Adding "Dynamic Masters" ability to DC/OS Terraform
This repo is being used as the PoC placeholder for sharing feedback, ideas, and results for adding the feature of being able to [replace a master](https://docs.mesosphere.com/1.12/administering-clusters/replacing-a-master-node/) into DC/OS Terraform. This is a feature only available within AWS and Azure currently which you can see is broken into sub folders `./aws` and `./azure`. Provider specifics will be provided in its own README.

For More information on this Feature, please visit the [docs.mesosphere.com](https://docs.mesosphere.com/1.12/administering-clusters/replacing-a-master-node/) page for more details. 

## Usage/Notes
Currently, we are making branches named `dynam-masters-poc` on each of the affected Repos for each provider and pointing the `source` within each `main.tf` to reference these instead of default (latest TF Registry). This is to keep track of the changes being made to them and for easy merge later on. Using branches vs local modules will be much simpler to collaborate and provide feedback as well.

Example:
``` 
  #source             = "dcos-terraform/dcos/aws"
  source              = "git::https://github.com/dcos-terraform/terraform-aws-dcos?ref=dynam-masters-poc"
```


Current `main.tf` uses the following defaults so it can be run directly out of the box:
- 3 Masters, 2 Private Agents, 1 Public Agent
- `~/.ssh/id_rsa.pub`
- Random Cluster Name 
- Install mode
- 1.11.7

Once we feel comfortable and we are ready to merge and release, we can uncomment original TF Registry source and remove ref.

## Testing Measures
- 1.11
- 1.12