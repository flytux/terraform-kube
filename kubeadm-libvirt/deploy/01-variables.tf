variable "password" { default = "linux" }

variable "ip_type" { default = "static" }

variable "prefixIP" { default = "192.168.122" }

variable "master_ip" { default = "192.168.122.11" }

variable "dns_domain" { default = "kubeworks.net" }

variable "diskPool" { default = "default" }

variable "qemu_connect" { default = "qemu:///system" }

variable "join_cmd" { default = "$(ssh -i $HOME/.ssh/id_rsa.key -o StrictHostKeyChecking=no 192.168.122.11 -- cat join_cmd)" }
variable "kubeadm_nodes" { 

  type = map(object({ role = string, octetIP = string , vcpu = number, memoryMB = number, incGB = number}))
  default = { 
              kubeadm-master-1 = { role = "master-init",   octetIP = "11" , vcpu = 2, memoryMB = 1024 * 8, incGB = 30},
              kubeadm-worker-1 = { role = "worker",        octetIP = "21" , vcpu = 2, memoryMB = 1024 * 8, incGB = 30}
              kubeadm-master-2 = { role = "master-member", octetIP = "12" , vcpu = 2, memoryMB = 1024 * 8, incGB = 30}
  }
}
