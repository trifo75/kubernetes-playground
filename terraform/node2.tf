# ----------------------------
# node2 container
# ----------------------------
resource "incus_instance" "node2" {
  name     = "node2"

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
# Configure node2 (SSH + admin + static IP)
# ----------------------------
resource "null_resource" "configure_node2" {
  depends_on = [incus_instance.node2]

  provisioner "local-exec" {
    command = <<EOT
# Install SSH server
incus exec node2 -- apt update
incus exec node2 -- apt install -y openssh-server apt-transport-https ca-certificates curl

# Create admin user with password
incus exec node2 -- useradd -m -s /bin/bash admin
incus exec node2 -- bash -c 'echo "admin:kubepass" | chpasswd'
incus exec node2 -- usermod -aG sudo admin

# Enable and start SSH
incus exec node2 -- systemctl enable ssh
incus exec node2 -- systemctl start ssh

# Configure static IP via netplan

incus exec node2 -- bash -c 'cat >/etc/netplan/50-static.yaml <<EOF
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: false
      addresses: [192.168.101.12/24]
      nameservers:
        addresses: [8.8.8.8,8.8.4.4]
      routes:
        - to: 0.0.0.0/0
          via: 192.168.101.1
EOF'

incus exec node2 -- chmod 600 /etc/netplan/50-static.yaml

# Apply netplan
incus exec node2 -- netplan apply
EOT
  }


}
