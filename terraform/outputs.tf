



output "_10_VMs_created" {
    value = local.vms
  
}

output "_20_Ansible_advice" {
    value = <<ENDOFADVICE
    
    Now go to ../ansible directory. You will find the newly generated inventory file.
    Adjust config.yml if you didn't yet.
    Run ansible-playbook preparenode.yml
ENDOFADVICE
}