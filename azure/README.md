# Dynamic Masters on Azure for DC/OS Terraform
All the things for Azure to enable and test ["Replaceable Master Nodes"](https://docs.mesosphere.com/1.12/administering-clusters/replacing-a-master-node/#master-discovery-master-http-loadbalancer) for DC/OS. This feature allows for users to store exhibitor backend on an Azure Storage Aaccount and place the Master Nodes behind an LB to prevent the need of a static master list in your DC/OS config.

The following repos require changes to be made in order to make this work and the work can be tracked on the `dynam-masters-poc` branch.

- [`terraform-azurem-dcos`](https://github.com/dcos-terraform/terraform-azurem-dcos/tree/dynam-masters-poc)

- [`terraform-azurem-infrastructure`](https://github.com/dcos-terraform/terraform-azurem-infrastructure/tree/dynam-masters-poc)


Please use the provided [`main.tf`](./main.tf) as a template for your deployment and note the following configs are required:

```
dcos_exhibitor_storage_backend
dcos_exhibitor_azure_account_name
dcos_exhibitor_azure_account_key
dcos_exhibitor_azure_prefix
dcos_master_discovery         
dcos_exhibitor_address        
dcos_num_masters
```

Also see configuration reference for [`master_discovery`](https://docs.mesosphere.com/1.12/installing/production/advanced-configuration/configuration-reference/#master-discovery-required) and [`exhibitor_storage_backend`](https://docs.mesosphere.com/1.12/installing/production/advanced-configuration/configuration-reference/#exhibitor-storage-backend) for more details.

## Usage
1) Pull down the repo. 
```
mkdir dynamic-masters && \
cd dynamic-masters && \
git clone git@github.com:dcos-terraform/dynamic-masters-poc.git && \
cd azure
```

2) Add values to the following variables in your `main.tf`
```
dcos_exhibitor_storage_backend
dcos_exhibitor_azure_account_name
dcos_exhibitor_azure_account_key
dcos_exhibitor_azure_prefix
dcos_master_discovery         
dcos_exhibitor_address        
dcos_num_masters
```

Example:
```
  dcos_exhibitor_storage_backend    = "azure"
  dcos_exhibitor_azure_account_name = "dcosexhibitor"
  dcos_exhibitor_azure_account_key  = "${module.dcos.azurem_storage_key}" #This gets created via storage account
  dcos_exhibitor_azure_prefix       = "exhibitor"
  dcos_master_discovery             = "master_http_loadbalancer"
  dcos_exhibitor_address            = "${module.dcos.masters-internal-loadbalancer} "#This is the LB we create with the wrapper script
  dcos_num_masters                  = "3"
```            

3) Create a file called `license.key` with your Enterprise license key.
```
echo 'YOUR-DCOS-LICENSE-asbad-1343x' > license.key
```

4) Issue the following Terraform Commands to have Terraform build your cluster.
```
az login
export ARM_SUBSCRIPTOION_ID="Your_Tenant_ID_alnsdfhls12345"
ssh-add ~/.ssh/id_rsa
terraform init 
terraform plan -out plan.out 
terraform apply plan.out
```

*NOTE: This method takes a bit longer than normal to become available. Exhibitor and Mesos Masters will have to restart several times before they are ready. Typically takes an additional 5-6 minutes before UI is ready.*

5) Taint the appropriate resources. Currently this will need to be done in 2 separate steps: The Instance and Prereqs resource and then the DC/OS Master install resource. *THIS IS STILL A WORK IN PROGRESS. PLEASE SEE [FINDINGS](../aws/FINDINGS.md) for more details.*

The following shows how we perform this for the Master 1 node. 

Pro Tip, you can use the following one-liner to help taint resources. You can use this to taint any resources from the output of:

```
terraform state list
```

```
# Taint Master 1 Instance and Prereqs. 
echo module.dcos.module.dcos-infrastructure.module.masters.module.dcos-master-instances.null_resource.instance-prereq[0] | sed 's/module\.//g;s/\(.*\)\.\(.*\.\)/\1\ \2/;s/]//g;s/\[/\./g' | xargs terraform taint -module


echo module.dcos.module.dcos-infrastructure.module.masters.module.dcos-master-instances.azurerm_virtual_machine.instance[0] | sed 's/module\.//g;s/\(.*\)\.\(.*\.\)/\1\ \2/;s/]//g;s/\[/\./g' | xargs terraform taint -module

```

Re-apply state.
```
terraform plan -out plan.out 
terraform apply plan.out
```

*This will destroy the Master node, create a new one and then reinstall the prereqs. You will eventually see the Master node go unhealthy and then disappear from the DC/OS UI.*

6) Once the prereqs are completed you will need to taint the Master's DC/OS install resource. This part is tricky currently due to the way that we currently provision and upgrade our DC/OS clusters with the DC/OS Install module. Since each Master Node is installed one at a time and then the Agent Nodes simaltaneously, certain parts of the process will fail due to DC/OS already being installed on the node. This is fine and when this happens, you can `untaint` the current resource to move on. 

Example:
```
module.dcos.module.dcos-install.module.dcos-masters-install.null_resource.master1 (remote-exec): Checking if DC/OS is already installed: FAIL (Currently installed)

module.dcos.module.dcos-install.module.dcos-masters-install.null_resource.master1 (remote-exec): Found an existing DC/OS installation. To reinstall DC/OS on this this machine you must
module.dcos.module.dcos-install.module.dcos-masters-install.null_resource.master1 (remote-exec): first uninstall DC/OS then run dcos_install.sh. To uninstall DC/OS, follow the product
module.dcos.module.dcos-install.module.dcos-masters-install.null_resource.master1 (remote-exec): documentation provided with DC/OS.


Error: Error applying plan:

1 error(s) occurred:

* module.dcos.module.dcos-install.module.dcos-masters-install.null_resource.master1: error executing "/tmp/terraform_948165397.sh": Process exited with status 1

Terraform does not automatically rollback in the face of errors.
Instead, your Terraform state file has been partially updated with
any resources that successfully completed. Please address the error
above and apply again to incrementally change your infrastructure.
```

Untaint the resource and move on!
```
echo module.dcos.module.dcos-core.module.dcos-masters-install.null_resource.master1 | sed 's/module\.//g;s/\(.*\)\.\(.*\.\)/\1\ \2/;s/]//g;s/\[/\./g'| xargs terraform untaint -module
```

Let's taint Master 1 master install resource and begin from there:
```
echo module.dcos.module.dcos-core.module.dcos-masters-install.null_resource.master1 | sed 's/module\.//g;s/\(.*\)\.\(.*\.\)/\1\ \2/;s/]//g;s/\[/\./g'| xargs terraform taint -module
```

Re-apply state.
```
terraform plan -out plan.out 
terraform apply plan.out
```

As mentioned, if the install fails due to DC/OS already being installed, just **untaint** that resource and move on.

**The Fun Part!** Once you find the correct Master to run the install on, you can actually watch DC/OS Replace the older Master Node with the new! During the Master install on the new master, login and tail the journal for the `dcos-exhibitor` service (It might take a sec for this service to appear depending on where the install process is).

```
sudo journalctl -fu dcos-exhibitor

...
...
...

# Eventually you will see a message like:
Dec 17 16:45:59 master-4-dcos-test1d38gb start_exhibitor.py[3414]: INFO  com.netflix.exhibitor.core.activity.ActivityLog  Automatic Instance Management will change the server list: 1:172.31.0.8,2:172.31.0.9,3:172.31.0.7 ==> 1:172.31.0.8,3:172.31.0.7,4:172.31.0.11 [ActivityQueue-0]

...
...
...
```

Once you see exhibitor begin accepting connections, tail the journal of the `dcos-mesos-master` service and you will begin to see syncing ZK.

```
sudo journalctl -fu dcos-mesos-master

...
...
...

# Eventually you will see messages like:
Dec 17 16:48:19 master-4-dcos-test1d38gb systemd[1]: Starting Mesos Master: distributed systems kernel...
Dec 17 16:48:19 master-4-dcos-test1d38gb mesos-master[7818]: PING ready.spartan (127.0.0.1) 56(84) bytes of data.
Dec 17 16:48:19 master-4-dcos-test1d38gb mesos-master[7818]: 64 bytes from localhost (127.0.0.1): icmp_seq=1 ttl=64 time=0.024 ms
Dec 17 16:48:19 master-4-dcos-test1d38gb mesos-master[7818]: --- ready.spartan ping statistics ---
Dec 17 16:48:19 master-4-dcos-test1d38gb mesos-master[7818]: 1 packets transmitted, 1 received, 0% packet loss, time 0ms
Dec 17 16:48:19 master-4-dcos-test1d38gb mesos-master[7818]: rtt min/avg/max/mdev = 0.024/0.024/0.024/0.000 ms
Dec 17 16:48:19 master-4-dcos-test1d38gb mesos-master[7821]: /proc/sys/net/ipv4/conf/all/rp_filter: 2
Dec 17 16:48:19 master-4-dcos-test1d38gb mesos-master[7821]: /proc/sys/net/ipv4/conf/default/rp_filter: 2
Dec 17 16:48:19 master-4-dcos-test1d38gb mesos-master[7821]: /proc/sys/net/ipv4/conf/docker0/rp_filter: 2
Dec 17 16:48:19 master-4-dcos-test1d38gb mesos-master[7821]: /proc/sys/net/ipv4/conf/dummy0/rp_filter: 2
Dec 17 16:48:19 master-4-dcos-test1d38gb mesos-master[7821]: /proc/sys/net/ipv4/conf/eth0/rp_filter: 2
Dec 17 16:48:19 master-4-dcos-test1d38gb mesos-master[7821]: /proc/sys/net/ipv4/conf/lo/rp_filter: 2
Dec 17 16:48:19 master-4-dcos-test1d38gb mesos-master[7821]: /proc/sys/net/ipv4/conf/minuteman/rp_filter: 2
Dec 17 16:48:19 master-4-dcos-test1d38gb mesos-master[7821]: /proc/sys/net/ipv4/conf/spartan/rp_filter: 2
Dec 17 16:48:21 master-4-dcos-test1d38gb mesos-master[7839]: [INFO] Clearing proxy environment variables
Dec 17 16:48:21 master-4-dcos-test1d38gb mesos-master[7839]: [INFO] Setting ENABLE_CHECK_TIME to true
Dec 17 16:48:21 master-4-dcos-test1d38gb mesos-master[7839]: Checking whether time is synchronized using the kernel adjtimex API.
Dec 17 16:48:21 master-4-dcos-test1d38gb mesos-master[7839]: Time can be synchronized via most popular mechanisms (ntpd, chrony, systemd-timesyncd, etc.)
Dec 17 16:48:21 master-4-dcos-test1d38gb mesos-master[7839]: Time is in sync!
Dec 17 16:48:21 master-4-dcos-test1d38gb mesos-master[7839]: [INFO] PID 5578 has command line [b'/opt/mesosphere/active/java/usr/java/bin/java', b'-Dzookeeper.log.dir=/var/lib/dcos/exhibitor/zookeeper', b'-Dzookeeper.root.logger=INFO,CONSOLE', b'-cp', b'/opt/mesosphere/active/exhibitor/usr/zookeeper/bin/../build/classes:/opt/mesosphere/active/exhibitor/usr/zookeeper/bin/../build/lib/*.jar:/opt/mesosphere/active/exhibitor/usr/zookeeper/bin/../lib/slf4j-log4j12-1.7.25.jar:/opt/mesosphere/active/exhibitor/usr/zookeeper/bin/../lib/slf4j-api-1.7.25.jar:/opt/mesosphere/active/exhibitor/usr/zookeeper/bin/../lib/netty-3.10.6.Final.jar:/opt/mesosphere/active/exhibitor/usr/zookeeper/bin/../lib/log4j-systemd-journal-appender-1.3.2.jar:/opt/mesosphere/active/exhibitor/usr/zookeeper/bin/../lib/log4j-jna-4.2.2.jar:/opt/mesosphere/active/exhibitor/usr/zookeeper/bin/../lib/log4j-1.2.17.jar:/opt/mesosphere/active/exhibitor/usr/zookeeper/bin/../lib/jline-0.9.94.jar:/opt/mesosphere/active/exhibitor/usr/zookeeper/bin/../lib/audience-annotations-0.5.0.jar:/opt/mesosphere/active/exhibitor/usr/zookeeper/bin/../zookeeper-3.4.13.jar:/opt/mesosphere/active/exhibitor/usr/zookeeper/bin/../src/java/lib/*.jar:/var/lib/dcos/exhibitor/conf:', b'-Djna.tmpdir=/var/lib/dcos/exhibitor/tmp', b'-Dzookeeper.DigestAuthenticationProvider.superDigest=super:lK75jTNcA+U9vtVEw5vB51mj/w4=', b'-Dcom.sun.management.jmxremote', b'-Dcom.sun.management.jmxremote.local.only=false', b'org.apache.zookeeper.server.quorum.QuorumPeerMain', b'/var/lib/dcos/exhibitor/conf/zoo.cfg']
Dec 17 16:48:21 master-4-dcos-test1d38gb mesos-master[7839]: [INFO] PID file hasn't been modified. ZK still seems to be at that PID.
Dec 17 16:48:21 master-4-dcos-test1d38gb mesos-master[7839]: [INFO] Shortcut succeeeded, assuming local zk is in good config state, not waiting for quorum.
Dec 17 16:48:21 master-4-dcos-test1d38gb mesos-master[7839]: [INFO] Make sure directory exists: /run/dcos/etc
Dec 17 16:48:21 master-4-dcos-test1d38gb mesos-master[7839]: [INFO] Make sure directory exists: /run/dcos/etc/dcos-diagnostics
Dec 17 16:48:21 master-4-dcos-test1d38gb mesos-master[7839]: [INFO] Make sure directory exists: /run/dcos/etc/dcos-checks
Dec 17 16:48:21 master-4-dcos-test1d38gb mesos-master[7839]: [INFO] Make sure directory exists: /run/dcos/etc/dcos-backup
Dec 17 16:48:21 master-4-dcos-test1d38gb mesos-master[7839]: [INFO] Make sure directory exists: /run/dcos/etc/dcos-cluster-linker
Dec 17 16:48:21 master-4-dcos-test1d38gb mesos-master[7839]: [INFO] Make sure directory exists: /run/dcos/etc/dcos-ca
Dec 17 16:48:21 master-4-dcos-test1d38gb mesos-master[7839]: [INFO] Make sure directory exists: /run/dcos/etc/dcos-iam-ldap-sync
Dec 17 16:48:21 master-4-dcos-test1d38gb mesos-master[7839]: [INFO] Make sure directory exists: /run/dcos/etc/history-service
Dec 17 16:48:21 master-4-dcos-test1d38gb mesos-master[7839]: [INFO] Make sure directory exists: /run/dcos/etc/marathon
Dec 17 16:48:21 master-4-dcos-test1d38gb mesos-master[7839]: [INFO] Make sure directory exists: /run/dcos/etc/mesos
Dec 17 16:48:21 master-4-dcos-test1d38gb mesos-master[7839]: [INFO] Make sure directory exists: /run/dcos/etc/mesos-dns
Dec 17 16:48:21 master-4-dcos-test1d38gb mesos-master[7839]: [INFO] Make sure directory exists: /run/dcos/etc/metronome
Dec 17 16:48:21 master-4-dcos-test1d38gb mesos-master[7839]: [INFO] Make sure directory exists: /run/dcos/etc/signal-service
Dec 17 16:48:21 master-4-dcos-test1d38gb mesos-master[7839]: [INFO] Make sure directory exists: /run/dcos/etc/telegraf
Dec 17 16:48:21 master-4-dcos-test1d38gb mesos-master[7839]: [INFO] Make sure directory exists: /run/dcos/pki/CA/certs
Dec 17 16:48:21 master-4-dcos-test1d38gb mesos-master[7839]: [INFO] Make sure directory exists: /run/dcos/pki/CA/private
Dec 17 16:48:21 master-4-dcos-test1d38gb mesos-master[7839]: [INFO] Make sure directory exists: /run/dcos/pki/tls/certs
Dec 17 16:48:21 master-4-dcos-test1d38gb mesos-master[7839]: [INFO] Make sure directory exists: /run/dcos/pki/tls/private
Dec 17 16:48:21 master-4-dcos-test1d38gb mesos-master[7839]: [INFO] Make sure directory exists: /run/dcos/pki/cockroach
Dec 17 16:48:21 master-4-dcos-test1d38gb mesos-master[7839]: [INFO] Using super credentials for Zookeeper
Dec 17 16:48:21 master-4-dcos-test1d38gb mesos-master[7839]: [INFO] Connecting to 127.0.0.1:2181
Dec 17 16:48:21 master-4-dcos-test1d38gb mesos-master[7839]: [INFO] Zookeeper connection established, state: CONNECTED
Dec 17 16:48:21 master-4-dcos-test1d38gb mesos-master[7839]: [DEBUG] bootstrapping dcos-mesos-master
Dec 17 16:48:21 master-4-dcos-test1d38gb mesos-master[7839]: [INFO] Initializing ACLs for znode /
...
...
...
Dec 17 16:48:26 master-4-dcos-test1d38gb mesos-master[7839]: [INFO] Reaching consensus about znode /dcos/master/secrets/zk/dcos_backup_master
Dec 17 16:48:27 master-4-dcos-test1d38gb mesos-master[7839]: [INFO] Consensus znode /dcos/master/secrets/zk/dcos_backup_master already exists
Dec 17 16:48:27 master-4-dcos-test1d38gb mesos-master[7839]: [INFO] ensure_zk_path(/dcos/master/secrets/zk, [ACL(perms=1, acl_list=['READ'], id=Id(scheme='digest', id='dcos-master:fMkMgKtR6Fl+wYKfdJg75Th6Vsc='))])
Dec 17 16:48:27 master-4-dcos-test1d38gb mesos-master[7839]: [INFO] Reaching consensus about znode /dcos/master/secrets/zk/dcos_bouncer
Dec 17 16:48:27 master-4-dcos-test1d38gb mesos-master[7839]: [INFO] Consensus znode /dcos/master/secrets/zk/dcos_bouncer already exists
Dec 17 16:48:27 master-4-dcos-test1d38gb mesos-master[7839]: [INFO] ensure_zk_path(/dcos/master/secrets/zk, [ACL(perms=1, acl_list=['READ'], id=Id(scheme='digest', id='dcos-master:fMkMgKtR6Fl+wYKfdJg75Th6Vsc='))])
Dec 17 16:48:27 master-4-dcos-test1d38gb mesos-master[7839]: [INFO] Reaching consensus about znode /dcos/master/secrets/zk/dcos_cluster_linker
Dec 17 16:48:27 master-4-dcos-test1d38gb mesos-master[7839]: [INFO] Consensus znode /dcos/master/secrets/zk/dcos_cluster_linker already exists
Dec 17 16:48:27 master-4-dcos-test1d38gb mesos-master[7839]: [INFO] ensure_zk_path(/dcos/master/secrets/zk, [ACL(perms=1, acl_list=['READ'], id=Id(scheme='digest', id='dcos-master:fMkMgKtR6Fl+wYKfdJg75Th6Vsc='))])
Dec 17 16:48:27 master-4-dcos-test1d38gb mesos-master[7839]: [INFO] Reaching consensus about znode /dcos/master/secrets/zk/dcos_cockroach
Dec 17 16:48:27 master-4-dcos-test1d38gb mesos-master[7839]: [INFO] Consensus znode /dcos/master/secrets/zk/dcos_cockroach already exists
Dec 17 16:48:27 master-4-dcos-test1d38gb mesos-master[7839]: [INFO] ensure_zk_path(/dcos/master/secrets/zk, [ACL(perms=1, acl_list=['READ'], id=Id(scheme='digest', id='dcos-master:fMkMgKtR6Fl+wYKfdJg75Th6Vsc='))])
...
...
...
```

7) The Agent Node(s) install will fail and you will need to untaint the resources to finally get your Terraform state back. You can use the for loop to clean it up:
```
for i in `terraform state list | grep agents-install.null_resource` ; do echo $i | sed 's/module\.//g;s/\(.*\)\.\(.*\.\)/\1\ \2/;s/]//g;s/\[/\./g' | xargs terraform untaint -module ; done
```

At anytime, you can also check your see the storage account created (Storage Account Name > Blob Containers > dcos-exhibitor > Azure Prefix). See [example](../exhibitor-file.example).


## Current Findings
See [FINDINGS](../aws/FINDINGS.md) page.

## Room to Improve?
- Keep the user from having to specify certain variables:

    `dcos_exhibitor_azure_account_key` - If storage account, backend, etc is set then use `${module.dcos.azurem_storage_key}`

    `dcos_exhibitor_azure_backend` - This will always be azure for Azure. 

    `dcos_exhibitor_address` - If storage account, backend, etc is set then use `${module.dcos.masters-internal-loadbalancer}`

    `dcos_exhibitor_azure_prefix` - should we set a default for this?

## Tested Versions (CentOS 7.5)
- 1.11.7 (successful)
- 1.12.0 (successful)