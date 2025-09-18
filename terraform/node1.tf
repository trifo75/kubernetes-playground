# ----------------------------
# Node1 container
# ----------------------------
resource "incus_instance" "node1" {
  name     = "node1"

  depends_on = [
    incus_profile.kubetest,
    incus_storage_pool.kubepool,
    incus_network.kubetest
  ]

  type     = "container"
  image    = "images:ubuntu/22.04"
  profiles = ["kubetest"]

  config = {
    # Enable loading kernel modules
    "linux.kernel_modules" = "overlay, br_netfilter"

    # Security/syscalls configs
    "security.syscalls.intercept.setxattr"    = "true"
    "security.syscalls.intercept.mknod"       = "true"
    "security.syscalls.intercept.mount"       = "true"

    # Also necessary for K8s in containers
    "security.nesting"    = "true"
    "security.privileged" = "true"

    # This is injecting necessary sysctl settings in the container
    # which were written in /etx/sysctl.d/99-kubernetes.conf if it were a normal host
    # (another way would be to set these on the host OS permanently)
    "raw.lxc" = <<-EOT
      lxc.sysctl.net.ipv4.ip_forward=1
      lxc.sysctl.net.bridge.bridge-nf-call-iptables=1
      lxc.sysctl.net.bridge.bridge-nf-call-ip6tables=1
    EOT

  }
}

# ----------------------------
# Configure node1 (SSH + admin + static IP)
# ----------------------------
resource "null_resource" "configure_node1" {
  depends_on = [incus_instance.node1]

  provisioner "local-exec" {
    command = <<EOT
# Install SSH server
incus exec node1 -- apt update
incus exec node1 -- apt install -y openssh-server

# Create admin user with password
incus exec node1 -- useradd -m -s /bin/bash admin
incus exec node1 -- bash -c 'echo "admin:kubepass" | chpasswd'
incus exec node1 -- usermod -aG sudo admin

# Enable and start SSH
incus exec node1 -- systemctl enable ssh
incus exec node1 -- systemctl start ssh

# Configure static IP via netplan
incus exec node1 -- bash -c 'cat >/etc/netplan/50-static.yaml <<EOF
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: false
      addresses: [192.168.101.11/24]
      nameservers:
        addresses: [8.8.8.8,8.8.4.4]
      routes:
        - to: 0.0.0.0/0
          via: 192.168.101.1
EOF'

# Apply netplan
incus exec node1 -- netplan apply
EOT
  }


}
