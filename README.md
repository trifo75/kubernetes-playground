# Installing Kubernetes the hard way
This is an experiment to create an automated install of a 3 node Kubernetes cluster - 1 master and 2 worker nodes.
The scripts are subject to furthr improvement, as there are hardcoded values where I should use variables anc cycles and flexible configurations. I will improve, I promise.

Kubernetes nodes need some special kernel settings that is not permitted on container instances by default. As system containers share the kernel of the host, along with its loaded modules and sysctl settings, we have to enable incus to ask the host to make the necessary settings on the start of the container instances. This is enabled using the `config { ... }` part of the instance creation. See comments there for explanation.

## Components used

* Incus system containers as virtualization layer
* terraform to automate provision of nodes
* Ansible to configure nodes further

## Directory structure

*terraform* - terraform code for node provision

*ansible* - Ansible scripts, config and inventory

## Prerequisites

* Incus installed
* terraform installed
* Ansible installed

## Usage

* in terraform directory run 'terraform plan' then 'terraform apply'. On successful completion created the 3 nodes as Ubuntu system containers, all with
  *  static IP configured
  *  user 'admin' with password 'kubepass' created
  *  sshd installed and started
  *  sudo for 'admin' user enabled
 
* in 'ansible' directory run 'ansible-playbook preparenodes.yml'. This does the following
   * enable pubkey auth from the host to the nodes as 'admin' and as 'root'
   * creates a keypair and distributes to the nodes to communicate with each other as admin or root
   * populates /etc/hosts files on nodes
   * populates known_hosts files for admin and root on all nodes
   * enable passwordless sudo for admin on all nodes
   * prepare kernel config for Kubernetes - this is broken yet
   * TODO install containerd
   * TODO continue with Kubernetes install

 ## status /  caveat

Incus system container cannot load kernel modules on it's own. Host system should load necessary modules and enable containers to use them usin sysctl - but how?
 
Incus instances should *ask* the host to load kernel parameters, using instance config option `linux.kernel_modules = [overlay, br_netfilter]` This way - as the container uses the hosts's kernel, required modules will be available in the container.

Other option is `security.syscalls.intercept.modprobe` - does this enable to forward the modprobe request from the container to the host?

## TODO

* reorganize terraform code to use variables and cycles
* reorganize cloud_init to get rid of the long list of injected commands