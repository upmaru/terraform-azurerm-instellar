resource "azurerm_public_ip" "bootstrap_node" {
  name                = "${var.identifier}-bootstrap-node-public-ip"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "bootstrap_node" {
  name                = "${var.identifier}-bootstrap-node-nic"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_ids[0]
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.bootstrap_node.id
  }
}

resource "azurerm_linux_virtual_machine" "bootstrap_node" {
  name                = "${var.identifier}-bootstrap-node"
  resource_group_name = var.resource_group.name
  location            = var.resource_group.location
  size                = var.node_size
  admin_username      = var.default_username

  connection {
    type                = "ssh"
    user                = var.default_username
    host                = self.private_ip_address
    private_key         = tls_private_key.bastion_key.private_key_openssh
    bastion_user        = var.default_username
    bastion_host        = azurerm_linux_virtual_machine.bastion.public_ip_address
    bastion_private_key = tls_private_key.terraform_cloud.private_key_openssh
  }

  network_interface_ids = [
    azurerm_network_interface.bootstrap_node.id
  ]

  provisioner "file" {
    content = templatefile("${path.module}/templates/lxd-init.yml.tpl", {
      ip_address   = self.private_ip_address
      server_name  = "${var.identifier}-bootstrap-node"
      storage_size = "${var.storage_size - 10}"
      vpc_ip_range = var.address_space
    })

    destination = "/tmp/lxd-init.yml"
  }

  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait",
      "lxd init --preseed < /tmp/lxd-init.yml"
    ]
  }

  os_disk {
    caching              = "ReadWrite"
    disk_size_gb         = var.storage_size
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = {
    blueprint = var.blueprint
  }
}