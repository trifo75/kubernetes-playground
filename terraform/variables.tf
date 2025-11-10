

variable "num_masters" {
    description = "Number of control-plane nodes"
    type        = number
    default     = 3
}


variable "num_workers" {
    description = "Number of worker nodes"
    type        = number
    default     = 4
}

variable "network_cidr" {
    description = "Create hosts in this network"
    default     = "192.168.101.0/24"
}

variable "master_vm_cfg" {
    default    = {
        cpu    = 2
        memory = 4096
    }
}

variable "worker_vm_cfg" {
    default    = {
        cpu    = 2
        memory = 4096
    }
}

variable "balancer_vm_cfg" {
    default    = {
        cpu    = 1
        memory = 2048
    }
}
