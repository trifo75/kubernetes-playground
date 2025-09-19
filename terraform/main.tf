terraform {
  required_providers {
    incus = {
      source  = "lxc/incus"
      version = ">=0.1.0"
    }
  }
}

provider "incus" {
  # Uses your local incus socket
}

# --- Network ---
resource "incus_network" "kube_br0" {
  name = "kube_br0"

  config = {
    "ipv4.address" = "192.168.101.1/24"
    "ipv4.nat"     = "true"
    "ipv6.address" = "none"
  }
}

# --- Storage pool ---
resource "incus_storage_pool" "kubepool" {
  name   = "kubepool"
  driver = "dir"

}

# --- Profile ---
resource "incus_profile" "kubelab" {
  name = "kubelab"

  depends_on = [
     incus_network.kube_br0,
     incus_storage_pool.kubepool
  ]

  description = "Kubernetes lab node"

  device {
    name = "eth0"
    type = "nic"
    properties = {
      network = incus_network.kube_br0.name
      name    = "eth0"
    }
  }

  device {
    name = "root"
    type = "disk"
    properties = {
      pool = incus_storage_pool.kubepool.name
      path = "/"
    }
  }

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

