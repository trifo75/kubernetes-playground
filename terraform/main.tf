terraform {
  required_providers {
    incus = {
      source  = "lxc/incus"
      version = "0.1.0"
    }
  }
}

provider "incus" {
  # Uses local Incus socket by default
}

# ----------------------------
# Storage pool
# ----------------------------
resource "incus_storage_pool" "kubepool" {
  name   = "kubepool"
  driver = "dir"

  config = {
    source = "/var/lib/incus/storage-pools/kubepool"
  }
}

# ----------------------------
# Network
# ----------------------------
resource "incus_network" "kubetest" {
  name = "kubetest"
  type = "bridge"

  config = {
    "ipv4.address" = "192.168.101.1/24"
    "ipv4.nat"     = "true"
    "ipv6.address" = "none"
  }
}

# ----------------------------
# Profile
# ----------------------------
resource "incus_profile" "kubetest" {
  name = "kubetest"

  depends_on = [incus_network.kubetest]

  device {
    name = "root"
    type = "disk"
    properties = {
      pool = "kubepool"
      path = "/"
    }
  }

  device {
    name = "eth0"
    type = "nic"
    properties = {
      network = "kubetest"
      name    = "eth0"
    }
  }
}


# ----------------------------
# Output IP
# ----------------------------
output "master_ip" {
  value = "192.168.101.10"
}
