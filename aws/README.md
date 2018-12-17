# Dynamic Masters on AWS for DC/OS Terraform
All the things for AWS to enable and test ["Replaceable Master Nodes"](https://docs.mesosphere.com/1.12/administering-clusters/replacing-a-master-node/#master-discovery-master-http-loadbalancer) for DC/OS. This feature allows for users to store exhibitor backend on S3 and place Master nodes behind a LB in order to keep from having to use a static master list. 

The following repos require changes to be made in order to make this work and the work can be tracked on the `dynam-masters-poc` branch.

- [`terraform-aws-dcos`](https://github.com/dcos-terraform/terraform-aws-dcos/tree/dynam-masters-poc)

- [`terraform-aws-infrastructure`](https://github.com/dcos-terraform/terraform-aws-infrastructure/tree/dynam-masters-poc)

- [`terraform-aws-iam`](https://github.com/dcos-terraform/terraform-aws-iam/tree/dynam-masters-poc)


Please use the provided [`main.tf`](./main.tf) as a template for your deployment and note the following configs are required:

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
Pull down the repo and make desire adjustments to `main.tf`. Also, drop your license key as `license.key`.

```
eval $(maws li account)
export AWS_DEFAULT_REGION="us-east-1"
ssh-add ~/.ssh/id_rsa
terraform init 
terraform plan -out plan.out 
terraform apply plan.out
```

NOTE: This method takes a bit longer than normal to become available. Exhibitor and Mesos Masters will have to restart several times before they are ready. Typically takes an additional 5-6 minutes before UI is ready.

Taint the resources. (WORK IN PROGRESS) PLEASE SEE [FINDINGS](./FINDINGS.md)
```
# Show all avail
terraform state list

# Taint resources accordinly. 
terraform taint -module dcos.dcos-install.dcos-masters-install null_resource.master1
terraform taint -module dcos.dcos-infrastructure.dcos-master-instances.dcos-master-instances aws_instance.instance.0
terraform taint -module dcos.dcos-infrastructure.dcos-master-instances.dcos-master-instances null_resource.instance-prereq.0
```

Re-apply state.
```
terraform plan -out plan.out 
terraform apply plan.out
```

**The Fun Part!** You can actually watch DC/OS Replace the older Master Node with the new! During the Master install on the new master, login and tail the journal for the `dcos-exhibitor` service (It might take a sec for this service to appear depending on where the install process is).

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

At anytime, you can also check your see bucket/prefix and download the file and view its contents. See [example](../exhibitor-file.example).


## Current Findings
See [FINDINGS](./FINDINGS.md) page.

## Room to Improve?
- Keep the user from having to specify certain variables:

    `dcos_exhibitor_storage_backend` - This will always be aws_s3 for aws

    `dcos_s3_prefix` - should we set a default for this?

    `dcos_exhibitor_address` - If bucket, backend, etc is set the use `${module.dcos.masters-internal-loadbalancer}`

## Tested Versions (CentOS 7.5)
- 1.11.7 (successful)
- 1.12.0 (successful)