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

* Incus installed - with quemu/libvirt backing
* terraform installed
* Ansible installed

## Usage

* in **terraform** directory run `terraform plan` then `terraform apply`. On successful completion created the 3 nodes as Ubuntu VM-s, all with
  *  static IP configured
  *  user `admin` with password `kubepass` created
  *  sshd installed and started
  *  sudo for `admin` user enabled
 
* in **ansible** directory run `ansible-playbook preparenodes.yml`. This does the following
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

* Log on `master` host  via `incus shell master` or `ssh root@192.168.101.10` and set up Kubernetes cluster
  * Run `kubeadm init --pod-network-cidr=10.244.0.0/16` this initialises the control-plane. Don't forget to set `--pod-network-cidr` parameter because without it pod network can not start, but `kubeadm` won't warn you about that. When successfully initialised, kubeadm will give a command with tokens needed to connect worker nodes. Like this: `kubeadm join 192.168.101.10:6443 --token clm3xc.exhryqyu8huronp6 --discovery-token-ca-cert-hash sha256:9b91013e81a06c87913cd01a6daa1fe5b4c7a5a1096c2e7c3c95e955a7e3ea06` - save this command in a file.
  * Choose a CNI plugin, like Flannel or Calico and install it. You can install it with
    ```
    export KUBECONFIG=/etc/kubernetes/admin.conf
    kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
    ```
  * Check if control plane status is `ready` - give it a minute or so
    ```
    root@master:~# kubectl get node
    NAME     STATUS   ROLES           AGE   VERSION
    master   Ready    control-plane   74m   v1.34.1
    ```
  * Add worker nodes: log in as root and run the `kubeadm join ...` command, which you saved earlier. After a minute you should see all worker nodes in `ready` status

## status /  caveat

We switched to use  VM-s in place of system containers, because running Kubernetes K8s in LXC system containers proved to be too close to impossible.

## Incus basics


Check if libvirtd is available:
`systemctl status libvirtd`

If it is not present, install quemu / libvirt to Ubuntu host
```
sudo apt update
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager
sudo systemctl enable --now libvirtd
```

The commands below create a test host in the way terraform should. This was necessary because of a struggle setting up hosts with static IP addresses without messing up name resolution.

Create an Incus network
`incus network create kube_br0 ipv4.address=192.168.101.1/24 ipv4.nat=true ipv6.address=none`

Create a storage pool to be used by vm-s
`incus storage create kubepool dir`

Set up Incus profile "kubelab", adding a default `eth0` network interface, connecting into `kube_br0` network and a root disk from `kubepool` storage pool
`incus profile create kubelab`
`incus profile device add kubelab eth0 nic network=kube_br0 name=eth0`
`incus profile device add kubelab root disk path=/ pool=kubepool`

Launch test image as a virtual machine to see if network is working
`incus launch images:ubuntu/22.04 testhost --profile kubelab -vm`
This way the host gets IP by DHCP and network is fully functional
now tear down instance
`incus delete testhost --force`

Recreate insance and config it to use static IP (192.168.101.15, selected from the range of `kube_br0` ridge adapter)
`incus create images:ubuntu/22.04 testhost --profile kubelab`
`incus config device override testhost eth0 ipv4.address=192.168.101.15`


## TODO

* reorganize terraform code to use variables and cycles
* implement wait time before destroying storage pool - 15s is enough after destroying instances


kubeadm join 192.168.101.10:6443 --token clm3xc.exhryqyu8huronp6 --discovery-token-ca-cert-hash sha256:9b91013e81a06c87913cd01a6daa1fe5b4c7a5a1096c2e7c3c95e955a7e3ea06

openssl s_client -connect master.local:443 -showcerts </dev/null 2>/dev/null \
  | openssl x509 -noout -text | grep -A1 "Subject Alternative Name"

