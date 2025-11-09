# --- Instance ---
resource "incus_instance" "nodes" {
  for_each = local.vms

  name     = each.value.hostname
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
      "ipv4.address" = each.value.ip_address
    }
  }

}


# We just wait until the VM-s are ready
# we try to run **systemctl** until it succeeds
resource "null_resource" "check_vm_ready" {
  for_each = incus_instance.nodes

  depends_on = [incus_instance.nodes]

  provisioner "local-exec" {
    command = <<-EOT
        timeout 120 bash -c 'until incus exec ${each.value.name} -- systemctl is-system-running --wait 2>/dev/null | grep -E "running|degraded"; do sleep 3; done'
    EOT
  }
}


# ----------------------------
# Configure VM (SSH + admin user)
# ----------------------------
resource "null_resource" "provision" {
  for_each = incus_instance.nodes

  depends_on = [null_resource.check_vm_ready]

  # Run commands
  provisioner "local-exec" {
    command = <<-EOT
      incus exec ${each.value.name} -- bash -c '
        apt-get update && \
        apt-get install -y openssh-server apt-transport-https ca-certificates curl 
        systemctl enable ssh
        systemctl start ssh
        useradd -m -s /bin/bash admin && \
        usermod -aG sudo admin &&\
        echo "admin:kubepass" | chpasswd ;\
      '
    EOT
  }
}


# ----------------------------
# Generate Ansible inventory file
# ----------------------------
resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../ansible/inventory"
  
  content = <<-EOT
[controlplane]
%{for k, v in local.vms~}
%{if v.node_type == "master" ~}
${k} ansible_ssh_host=${v.ip_address} 
%{endif~}
%{endfor~}

[workerplane]
%{for k, v in local.vms~}
%{if v.node_type == "worker" ~}
${k} ansible_ssh_host=${v.ip_address} 
%{endif~}
%{endfor~}

[balancers]
%{for k, v in local.vms~}
%{if v.node_type == "balancer" ~}
${k} ansible_ssh_host=${v.ip_address} 
%{endif~}
%{endfor~}

[kubernetes:children]
controlplane
workerplane

[all:vars]
EOT

  depends_on = [incus_instance.nodes]
}