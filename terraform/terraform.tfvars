
# Here masters and workers will differ only in the names:
# master1, master2, ...
# worker1, worker2, ...

# Number of master nodes to create
num_masters = 3

# Number of worker nodes to create
num_workers = 4

# Choose network range to be used by VM-s
# consider choosing big enough network to accomodate the address of the bridge
# and all the nodes so it should be at least /28
network_cidr = "192.168.211.0/24"
