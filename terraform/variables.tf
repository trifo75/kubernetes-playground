
# Variable with validation
variable "kubernetes_version" {
  description = "Desired version of kubernetes to be installed"
  type        = string
  default     = "1.33.1"

#   validation {
#     condition     = can(regex("^us-", var.region))
#     error_message = "Region must be in the United States (us-*)."
#   }
}

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

