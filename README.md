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
 
* in 'ansible' directory run 'ansible-playbook -k -K preparenodes.yml'. This does the following
   * asks for connection password - provide password 'kubepass"
   * enable pubkey auth from the host to the nodes as 'admin' and as 'root'
   * creates a keypair and distributes to the nodes to communicate with each other as admin or root
   * populates /etc/hosts files on nodes
   * populates known_hosts files for admin and root on all nodes
   * enable passwordless sudo for admin on all nodes
   * prepare kernel config for Kubernetes - this is broken yet
   * install containerd
   * install (and set hold) Kubernetes packages: kubelet, kubeadm and kubectl

   **Warning:** Ansible is configured in a highly insecure way: plain text password saved in the project directory in the file *very_insecure_password_file*. Also ansible.cfg is configured to read connection password and become password from this file when passwordless pubkey auth is not configured yet towards the nodes.

   **Warning** In this environement every node has only one IP address. If you create an env where there are multiple addresses configured, you have to make sure `kubelet` is using one that is able to communivate with other nodes. For example VirtualBox Nat adapters can be used to reach the internet, but no communication between the nodes. Then you must explicitly tell which address is to be used by kubelet. You can set this in `/etc/default/kubelet` file, as follows:
   `KUBELET_EXTRA_ARGS='--node-ip 111.222.33.44'`
   Obviously edit content for your needs.

 ## status /  caveat

Incus system container cannot load kernel modules on it's own.
 
Incus instances should *ask* the host to load kernel parameters, using instance config option `linux.kernel_modules = [overlay, br_netfilter]` This way - as the container uses the hosts's kernel, required modules will be available in the container.

Other option is `security.syscalls.intercept.modprobe` - does this enable to forward the modprobe request from the container to the host?

In my host OS I have a kernel which lacks `/proc/config.gz` so `kubeadm init` fails on pre-flight check. Here is what to check manually:
* `lsmod | grep -E 'overlay|br_netfilter|nf_conntrack|ip_tables|ip_vs'`
* `sysctl net.bridge.bridge-nf-call-iptables`
* `sysctl net.ipv4.ip_forward`
* `mount | grep cgroup`

`kubeadm init` still fails. The error is: required cgroups disabled




## Incus basics

These commands create a test host in the way terraform should. This was necessary because of a struggle setting up hosts with static IP addresses without messing up name resolution.

Incus network creation by hand.
`incus network create kube_br0 ipv4.address=192.168.101.1/24 ipv4.nat=true ipv6.address=none`

Storage pool creation
`incus storage create kubepool dir`

Set up Incus profile "kubelab", adding a default `eth0` network interface, connecting into `kube_br0` network and a root disk from `kubepool` storage pool
`incus profile create kubelab`
`incus profile device add kubelab eth0 nic network=kube_br0 name=eth0`
`incus profile device add kubelab root disk path=/ pool=kubepool`

Launch test image to see if network is working
`incus launch images:ubuntu/22.04 testhost --profile kubelab`
This way the host gets IP by DHCP and network is fully functional
now tear down instance
`incus delete testhost --force`

Recreate insance and config it to use static IP
`incus create images:ubuntu/22.04 testhost --profile kubelab`
`incus config device override testhost eth0 ipv4.address=192.168.101.15`


## TODO

* reorganize terraform code to use variables and cycles
* implement wait time before destroying storage pool - 15s is enough after destroying instances