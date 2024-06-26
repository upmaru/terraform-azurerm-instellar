locals {
  ssh_keys = {
    for i, key in var.ssh_keys :
    key => i
  }
}

resource "azurerm_public_ip" "bastion" {
  name                = "${var.identifier}-bastion-public-ip"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "bastion" {
  name                = "${var.identifier}-bastion-nic"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_ids[0]
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.bastion.id
  }
}

resource "azurerm_linux_virtual_machine" "bastion" {
  name                = "${var.identifier}-bastion"
  resource_group_name = var.resource_group.name
  location            = var.resource_group.location
  size                = var.bastion_size
  admin_username      = var.default_username

  network_interface_ids = [
    azurerm_network_interface.bastion.id
  ]

  admin_ssh_key {
    username   = var.default_username
    public_key = tls_private_key.terraform_cloud.public_key_openssh
  }

  dynamic "admin_ssh_key" {
    for_each = local.ssh_keys

    content {
      username   = var.default_username
      public_key = data.azurerm_ssh_public_key.user_key[admin_ssh_key.value].public_key
    }
  }

  connection {
    type        = "ssh"
    user        = var.default_username
    host        = self.public_ip_address
    private_key = tls_private_key.terraform_cloud.private_key_openssh
  }

  provisioner "file" {
    content     = tls_private_key.bastion_key.private_key_openssh
    destination = "/home/ubuntu/.ssh/id_rsa"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 600 /home/ubuntu/.ssh/id_rsa"
    ]
  }

  os_disk {
    caching              = "ReadWrite"
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

resource "azurerm_network_security_group" "bastion" {
  name                = "${var.identifier}-bastion-nsg"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name

  tags = {
    blueprint = var.blueprint
  }
}

resource "azurerm_application_security_group" "bastion" {
  name                = "${var.identifier}-bastion-asg"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name

  tags = {
    blueprint = var.blueprint
  }
}

resource "azurerm_network_interface_application_security_group_association" "bastion" {
  network_interface_id          = azurerm_network_interface.bastion.id
  application_security_group_id = azurerm_application_security_group.bastion.id
}

resource "azurerm_network_security_rule" "allow_ssh" {
  count = var.bastion_ssh ? 1 : 0

  name                        = "${var.identifier}-bastion-ssh-sg-rule"
  priority                    = 100
  resource_group_name         = var.resource_group.name
  network_security_group_name = azurerm_network_security_group.bastion.name
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_application_security_group_ids = [
    azurerm_application_security_group.bastion.id
  ]
  direction = "Inbound"
  protocol  = "Tcp"
  access    = "Allow"
}

resource "azurerm_network_interface_security_group_association" "bastion_ip_rule_association" {
  network_interface_id      = azurerm_network_interface.bastion.id
  network_security_group_id = azurerm_network_security_group.bastion.id
}