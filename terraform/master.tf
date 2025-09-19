# --- Instance ---
resource "incus_instance" "master" {
  name     = "master"
  image    = "images:ubuntu/22.04"
  profiles = [incus_profile.kubelab.name]

  depends_on = [
    incus_profile.kubelab
  ]

  device {
    name = "eth0"
    type = "nic"
    properties = {
      "network"      = incus_network.kube_br0.name
      "name"         = "eth0"
      "ipv4.address" = "192.168.101.10"
    }
  }

  file {
    content = "Kuskubus gyémánf félkrajcárja"
    target_path = "/fileup.txt"
  }

}

# ----------------------------
# Configure master (SSH + admin user)
# ----------------------------
resource "null_resource" "configure_master" {
  depends_on = [incus_instance.master]

  provisioner "local-exec" {
    command = <<EOT
# Install software
incus exec master -- apt update
incus exec master -- apt install -y openssh-server apt-transport-https ca-certificates curl

# Create admin user with password
incus exec master -- useradd -m -s /bin/bash admin
incus exec master -- bash -c 'echo "admin:kubepass" | chpasswd'
incus exec master -- usermod -aG sudo admin

# Enable and start SSH
incus exec master -- systemctl enable ssh
incus exec master -- systemctl start ssh

EOT
  }
}
