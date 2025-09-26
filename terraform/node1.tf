# --- Instance ---
resource "incus_instance" "node1" {
  name     = "node1"
  image    = "images:ubuntu/22.04"
  profiles = [incus_profile.kubelab.name]
  type = "virtual-machine"

  depends_on = [
    incus_profile.kubelab
  ]

  device {
    name = "eth0"
    type = "nic"
    properties = {
      "network"      = incus_network.kube_br0.name
      "name"         = "eth0"
      "ipv4.address" = "192.168.101.11"
    }
  }

  # file {
  #   content = "KUBELET_EXTRA_ARGS='--fail-swap-on=false'"
  #   target_path = "/etc/default/kubelet"
  # }

}

# ----------------------------
# Configure node1 (SSH + admin user)
# ----------------------------
resource "null_resource" "configure_node1" {
  depends_on = [incus_instance.node1]

  provisioner "local-exec" {
    command = <<EOT
# Install software
incus exec node1 -- apt update
incus exec node1 -- apt install -y openssh-server apt-transport-https ca-certificates curl

# Create admin user with password
incus exec node1 -- useradd -m -s /bin/bash admin
incus exec node1 -- bash -c 'echo "admin:kubepass" | chpasswd'
incus exec node1 -- usermod -aG sudo admin

# Enable and start SSH
incus exec node1 -- systemctl enable ssh
incus exec node1 -- systemctl start ssh

#incus file push /boot/config-$(uname -r) node1/boot/config-$(uname -r)

EOT
  }
}
