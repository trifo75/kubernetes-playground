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
  * Run `kubeadm init --pod-network-cidr=10.244.0.0/16` this initialises the control-plane. Don't forget to set `--pod-network-cidr=10.244.0.0/16` parameter because without it pod network can not start, but `kubeadm` won't warn you about that. When successfully initialised, kubeadm will give a command with tokens needed to connect worker nodes. Like this: `kubeadm join 192.168.101.10:6443 --token clm3xc.exhryqyu8huronp6 --discovery-token-ca-cert-hash sha256:9b91013e81a06c87913cd01a6daa1fe5b4c7a5a1096c2e7c3c95e955a7e3ea06` - save this command in a file.
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

We switched to use  VM-s in place of system containers, because running Kubernetes K8s in LXC system containers proved to be too close to impossible. Now ater running terraform and ansible, you have the master node ready to run `kubeadm init` and and worker nodes ready to join. On WSL you might need the extra step to enable NAT on the bridge to let nodes access the internet. Use the `misc/incus-nat-setup-for-WSL.sh` script. This script relies on the existence of `kube_br0` interface, so you can not run it before terraform creates the interface, but terraform will fail to configure the nodes without accessing internet - needed to install sshd. Second run of terraform might help.

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

## Testing on WSL2

* *WARNING* in WSL you might not have NAT passthrough enabled. To circumvent this, run `misc/incus-nat-setup-for-WSL.sh` which will enable NAT temporarily to the `kube_br0` interface. Catch: this is created *during* terraform.

* install quemu, libvirt, and incus (incus is better to be installed from zabbly repo)
```
sudo apt update
sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils python3 incus gnupg software-properties-common curl -y
```


* install terraform from Hashicorp repo
```
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update
sudo apt install -y terraform
```

* install incus from the Zabby repo
```
curl -fsSL https://pkgs.zabbly.com/key.asc -o /etc/apt/keyrings/zabbly.asc
echo "deb [signed-by=/etc/apt/keyrings/zabbly.asc] https://pkgs.zabbly.com/incus/stable $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/zabbix.list
sudo apt update
sudo apt install -y incus
```
* add local user to `incus` and `incus-admin` groups (my local username is 'trifo')
`sudo usermod -aG incus,incus-admin trifo`

* logoff and logon to apply changes user settings

* Initialise Incus environement.
run `incus admin init` 
**TODO** directions about what to set during init

* install ansible into a Python virtualenv 
```
python3 -m venv ~/ansible-venv   # create python virtual env
. ~/ansible-venv/bin/activate    # sourcing activate script
pip install ansible              # do the install
ansible --version                # check install
```

* Remove installed stuff and clean up
When testing is done, all data and installed software can be eliminated. First destroy virtual infrastructure:
in terraform directory run `terraform destroy -auto-approve`. This deletes all relevant virtual machines and config they relied on.
If you want to clean installed software as vell, then:
```
sudo apt remove --purge qemu-system-x86 qemu-kvm libvirt-clients libvirt-daemon-system bridge-utils terraform incus -y
sudo apt autoremove -y
sudo rm /etc/apt/sources.list.d/zabbly.list
sudo rm /etc/apt/sources.list.d/hashicorp.list
sudo apt clean  # Is this enough to get rid of all cached elements?
```

## TODO

* reorganize terraform code to use variables and cycles
* implement wait time before destroying storage pool - 15s is enough after destroying instances
* set FQDN hostnames for nodes. (`master` -> `master.kubernetes.local`)
