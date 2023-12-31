resource "random_string" "token" {
  length           = 108
  special          = true
  numeric          = true
  lower            = true
  upper            = true
  override_special = ":"
}

resource "tls_private_key" "generic-ssh-key" {
  algorithm = "RSA"
  rsa_bits  = 4096

  provisioner "local-exec" {
    command = <<EOF
      mkdir -p .ssh-${terraform.workspace}/
      echo "${tls_private_key.generic-ssh-key.private_key_openssh}" > .ssh-${terraform.workspace}/id_rsa.key
      echo "${tls_private_key.generic-ssh-key.public_key_openssh}" > .ssh-${terraform.workspace}/id_rsa.pub
      chmod 400 .ssh-${terraform.workspace}/id_rsa.key
      chmod 400 .ssh-${terraform.workspace}/id_rsa.key
    EOF
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOF
      rm -rvf .ssh-${terraform.workspace}/
    EOF
  }
}

data "template_file" "master-init" {
  template = file("artifacts/templates/master-init.sh")
  vars = {
    token     = random_string.token.result
    k3s_version = var.k3s_version
  }
}

data "template_file" "master-member" {
  template = file("artifacts/templates/master-member.sh")
  vars = {
    token     = random_string.token.result
    master_ip = var.master_ip
    k3s_version = var.k3s_version
  }
}

data "template_file" "worker" {
  template = file("artifacts/templates/worker.sh")
  vars = {
    token     = random_string.token.result
    master_ip = var.master_ip
    k3s_version = var.k3s_version
  }
}


# OS images for libvirt VMs
resource "libvirt_volume" "os_images" {
  depends_on = [libvirt_network.nat]
  for_each = var.k3s_nodes
  name   = "${each.key}.qcow2"
  pool   = var.diskPool
  source = "images/ubuntu-20.04-server-cloudimg-amd64.img"
  format = "qcow2"

# Extend libvirt primary volume
  provisioner "local-exec" {
    command = <<EOF
      echo "Increment disk size by ${each.value.incGB}GB"
      sleep 10
      poolPath=$(virsh --connect ${var.qemu_connect} pool-dumpxml ${var.diskPool} | grep -Po '<path>\K[^<]+')
      sudo qemu-img resize $poolPath/${each.key}.qcow2 +${each.value.incGB}G
      sudo chgrp libvirt $poolPath/${each.key}.qcow2
      sudo chmod g+w $poolPath/${each.key}.qcow2
    EOF
  }
}

# Create cloud init disk
resource "libvirt_cloudinit_disk" "cloudinit_disks" {
  for_each = var.k3s_nodes
  name           = "${each.key}-cloudinit.iso"
  pool           = var.diskPool
  user_data      = data.template_file.cloud_inits[each.key].rendered
}

# Configure cloud-init 
data "template_file" "cloud_inits" {
  for_each = var.k3s_nodes
  template = file("${path.module}/artifacts/config/cloud_init.cfg")
  vars = {
    hostname = each.key
    fqdn     = "${each.key}.${var.dns_domain}"
    password = var.password
    public_key = "${tls_private_key.generic-ssh-key.public_key_openssh}"
  }
}


resource "libvirt_network" "nat" {

  name = "${var.network_name}"
  mode = "nat"
  addresses = [ "${var.prefixIP}.0/24" ]

  domain = "kw01"
  dns {
    enabled = true
    local_only = true
  }
  dhcp { enabled = false }
  autostart = true
}
