

locals {

  # We get the first address from the network CIDR and add the mask part
  # to generate the address for the Incus bridge creation
  bridge_address = format("%s/%s", 
    cidrhost(var.network_cidr, 1), 
    element(split("/", var.network_cidr), 1)
  )

  # The first address from the network is given to the network bridge
  # so the minimum offset is 2
  # We can use othe offsets to generate "nice looking" addresses
  ip_start_offset = 2

  vms = merge(
    # Master nodes
    {
      for i in range(var.num_masters) :
      "master${i + 1}" => {
        hostname      = "master${i + 1}"
        ip_address    = cidrhost(var.network_cidr, local.ip_start_offset + i)
        role          = "master"
        node_type     = "master"
        cpu           = 2
        memory        = 4096
        # disk_size     = 50
        is_master     = true
        index         = i + 1
        tags = {
          Name        = "master${i + 1}"
          Role        = "master"
        }
      }
    },
    # Worker nodes
    {
      for i in range(var.num_workers) :
      "worker${i + 1}" => {
        hostname      = "worker${i + 1}"
        ip_address    = cidrhost(var.network_cidr, local.ip_start_offset + var.num_masters + i)
        role          = "worker"
        node_type     = "worker"
        cpu           = 4
        memory        = 8192
        # disk_size     = 100
        is_master     = false
        index         = i + 1
        tags = {
          Name        = "worker${i + 1}"
          Role        = "worker"
        }
      }
    },
    {
      for i in range(1) :
      "balancer${i + 1}" => {
        hostname      = "balancer${i + 1}"
        ip_address    = cidrhost(var.network_cidr, local.ip_start_offset + var.num_masters + var.num_workers + i)
        role          = "balancer"
        node_type     = "balancer"
        cpu           = 1
        memory        = 1024
        # disk_size     = 100
        is_master     = false
        index         = i + 1
        tags = {
          Name        = "balancer${i + 1}"
          Role        = "balancer"
        }
      }
    }

  )


}


