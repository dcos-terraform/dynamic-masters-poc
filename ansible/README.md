# Anisble Bridge + Infrastructure Module for Dynamic Masters
This repo utilizes the infrastructure module for both `./aws` or `./azure` and combines administration of the prereqs and DC/OS install through Ansible. The purpose of this repo is to provide the user with options and flexibility based on how they would like to manage their DC/OS Cluster. This demonstrates how it is possible to do so with your own Anisble Roles or the provided as examples.

The following repo required changes to the following repo:

- [`terraform-localfile-dcos-ansible-bridge](https://github.com/dcos-terraform/terraform-localfile-dcos-ansible-bridge/tree/dynam-masters-poc)

Please use the provided `main.tf` and Ansible files for your desired Provider (`./aws` or `./azure`).

## Notes
The Ansbile Bridge module is responsible for generating both an inventory (`./hosts`) file and a yaml file for your DC/OS Configs (`./dcos.yml`) based on the variables that you provide. To see an exhaustive list of available variables that you can use for your DC/OS configs please see the branches [README](https://github.com/dcos-terraform/terraform-localfile-dcos-ansible-bridge/tree/dynam-masters-poc). *Please note that this extensive list of variables has not been tested so you may have to make changes accordingly to the dcos.yml to make it work.*

Each time there is a change to the instances, Terraform will automatically make appropriate changes to the inventory. That being said, this is also the case if you make a change to the DC/OS Config variables as well. Changes to this yaml file has not been tested. Feel free to modify any of the Ansible files in the directory to your liking. You will see that we will need to do some custom actions to make this work in the Usage. *Remember this is just a demonstration*

## Usage
