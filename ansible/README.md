# Anisble Bridge + Infrastructure Module for Dynamic Masters
This repo utilizes the infrastructure module for both `./aws` or `./azure` and combines administration of the prereqs and DC/OS install through Ansible. The purpose of this repo is to provide the user with options and flexibility based on how they would like to manage their DC/OS Cluster. This demonstrates how it is possible to do so with your own Anisble Roles or the provided as examples.

The following repo required changes to the following repo:

- [`terraform-localfile-dcos-ansible-bridge`](https://github.com/dcos-terraform/terraform-localfile-dcos-ansible-bridge/tree/dynam-masters-poc)

Please use the provided `main.tf` and Ansible files for your desired Provider (`./aws` or `./azure`).

## Notes
The Ansbile Bridge module is responsible for generating both an inventory (`./hosts`) file and a yaml file for your DC/OS Configs (`./dcos.yml`) based on the variables that you provide. To see an exhaustive list of available variables that you can use for your DC/OS configs please see the branches [README](https://github.com/dcos-terraform/terraform-localfile-dcos-ansible-bridge/tree/dynam-masters-poc). *Please note that this extensive list of variables has not been tested so you may have to make changes accordingly to the dcos.yml to make it work.*

Each time there is a change to the instances, Terraform will automatically make appropriate changes to the inventory. That being said, this is also the case if you make a change to the DC/OS Config variables as well. Changes to this yaml file has not been tested. Feel free to modify any of the Ansible files in the directory to your liking. You will see that we will need to do some custom actions to make this work in the Usage. *Remember this is just a demonstration*

## Usage
Pull down the repo, change to the `ansible/aws` directory and make desire adjustments to `main.tf`. Also, drop your license key as `license.key`.

```
eval $(maws li account)
export AWS_DEFAULT_REGION="us-east-1"
ssh-add ~/.ssh/id_rsa
terraform init 
terraform plan -out plan.out 
terraform apply plan.out
```

When infrastructure has been provisioned, you will see that the `./hosts` and `/.dcos.yml`. For this demonstration to work, you will need to modify and actually move the `./dcos.yml` file.

Add the following lines to the `./dcos.yml` file under `dcos:`:

```
  download: "https://downloads.mesosphere.com/dcos-enterprise/stable/commit/20fa047bbd37188ccb55f61ab9590edc809030ec/dcos_generate_config.ee.sh"
  version: "1.12.0"
  # version_to_upgrade_from: "1.12.0-dev"
  # image_commit: "acc9fe548aea5b1b5b5858a4b9d2c96e07eeb9de"
  enterprise_dcos: true
```

*Finished file should look something like `group_vars/all/dcos.yaml.example`.*

Move `/.dcos.yml` to `group_vars/all/`.

```
mv dcos.yml group_vars/all/
```

Run the install playbook (NOTE: this will take several minutes to complete. It is installing all DC/OS Prereqs and installing DC/OS on all Masters and Agents. Masters also take some time to coordinate and set up with this feature as well.)
```
ansible-playbook install.yml
```

If the ansible playbook fails at any given time, simply re-run it. 

Once complete, you can go to the `cluster-url` output in your browser. It will become available when Masters coordinate.

Login with `bootstrapuser` and `deleteme`. 

**The Fun Part!** Once DC/OS is up, you can login and see all 3 Masters, taint one of the Master instances so that it will re-create a new one. 

```
echo module.dcos-infrastructure.module.dcos-master-instances.module.dcos-master-instances.aws_instance.instance[0] | sed 's/module\.//g;s/\(.*\)\.\(.*\.\)/\1\ \2/;s/]//g;s/\[/\./g' | xargs terraform taint -module
```

Re-apply.
```
terraform plan -out plan.out
terraform apply plan.out
```

The `./hosts` file will be updated to reflect the new Master IP. 

Re-run the `install.yml` playbook. 

```
ansible-playbook install.yml
```

the Master install on the new master, login and tail the journal for the `dcos-exhibitor` service (It might take a sec for this service to appear depending on where the install process is).

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

You can repeat the process of tainting and re-creating a master as many times as you would like. Note that in this setup ONLY 1 Master can be replaced at a time!

When finished, destroy all the things. Currently you will have to manually delete the S3 bucket.

```
terraform destroy
```

## Current Findings


## Room to Improve?


## Tested Versions (CentOS 7.5)
- 1.12.0 (successful)