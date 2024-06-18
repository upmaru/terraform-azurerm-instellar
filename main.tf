locals {
  topology = {
    for index, node in var.cluster_topology :
    node.name => merge(node, { subnet = node.id % length(var.subnet_ids) })
  }
}

resource "ssh_resource" "trust_token" {
  host         = azurerm_linux_virtual_machine.bootstrap_node.private_ip_address
  bastion_host = azurerm_linux_virtual_machine.bastion.public_ip_address

  user         = var.default_username
  bastion_user = var.default_username

  private_key         = tls_private_key.bastion_key.private_key_openssh
  bastion_private_key = tls_private_key.terraform_cloud.private_key_openssh

  commands = [
    "lxc config trust add --name instellar | sed '1d; /^$/d'"
  ]
}


resource "azurerm_public_ip" "bootstrap_node" {
  name                = "${var.identifier}-bootstrap-node-public-ip"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name
  allocation_method   = "Static"
  sku                 = "Standard"
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

  admin_ssh_key {
    username   = var.default_username
    public_key = tls_private_key.bastion_key.public_key_openssh
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

resource "azurerm_public_ip" "nodes" {
  for_each = local.topology

  name                = "${var.identifier}-node-${each.key}-public-ip"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    blueprint = var.blueprint
  }
}

resource "azurerm_network_interface" "nodes" {
  for_each = local.topology

  name                = "${var.identifier}-node-${each.key}-nic"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_ids[each.value.subnet]
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.nodes[each.key].id
  }
}

resource "azurerm_linux_virtual_machine" "nodes" {
  for_each = local.topology

  name                = "${var.identifier}-node-${each.key}"
  resource_group_name = var.resource_group.name
  location            = var.resource_group.location
  size                = each.value.size
  admin_username      = var.default_username

  network_interface_ids = [
    azurerm_network_interface.nodes[each.key].id
  ]

  connection {
    type                = "ssh"
    user                = var.default_username
    host                = self.private_ip_address
    private_key         = tls_private_key.bastion_key.private_key_openssh
    bastion_user        = var.default_username
    bastion_host        = azurerm_linux_virtual_machine.bastion.public_ip_address
    bastion_private_key = tls_private_key.terraform_cloud.private_key_openssh
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/lxd-join.yml.tpl", {
      ip_address   = self.private_ip_address
      join_token   = ssh_resource.cluster_join_token[each.key].result
      storage_size = "${var.storage_size - 10}"
    })

    destination = "/tmp/lxd-join.yml"
  }

  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait",
      "lxd init --preseed < /tmp/lxd-join.yml"
    ]
  }

  admin_ssh_key {
    username   = var.default_username
    public_key = tls_private_key.bastion_key.public_key_openssh
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

resource "ssh_resource" "cluster_join_token" {
  for_each = local.topology

  host         = azurerm_linux_virtual_machine.bootstrap_node.private_ip_address
  bastion_host = azurerm_linux_virtual_machine.bastion.public_ip_address

  user         = var.default_username
  bastion_user = var.default_username

  private_key         = tls_private_key.bastion_key.private_key_openssh
  bastion_private_key = tls_private_key.terraform_cloud.private_key_openssh

  commands = [
    "lxc cluster add ${var.identifier}-node-${each.key} | sed '1d; /^$/d'"
  ]
}

resource "azurerm_network_security_group" "nodes" {
  name                = "${var.identifier}-nodes-nsg"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name

  tags = {
    blueprint = var.blueprint
  }
}

resource "azurerm_application_security_group" "nodes" {
  name                = "${var.identifier}-nodes-asg"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name

  tags = {
    blueprint = var.blueprint
  }
}

resource "azurerm_network_interface_application_security_group_association" "bootstrap_node" {
  network_interface_id          = azurerm_network_interface.bootstrap_node.id
  application_security_group_id = azurerm_application_security_group.nodes.id
}

resource "azurerm_network_interface_application_security_group_association" "nodes" {
  for_each = local.topology

  network_interface_id          = azurerm_network_interface.nodes[each.key].id
  application_security_group_id = azurerm_application_security_group.nodes.id
}

resource "azurerm_network_security_rule" "nodes_from_bastion" {
  name                        = "${var.identifier}-nodes-from-bastion-sg-rule"
  network_security_group_name = azurerm_network_security_group.nodes.name
  priority                    = 100
  resource_group_name         = var.resource_group.name
  source_port_range           = "*"
  destination_port_range      = "22"
  source_application_security_group_ids = [
    azurerm_application_security_group.bastion.id
  ]
  destination_application_security_group_ids = [
    azurerm_application_security_group.nodes.id
  ]
  direction = "Inbound"
  protocol  = "Tcp"
  access    = "Allow"
}

resource "azurerm_network_interface_security_group_association" "bootstrap_node" {
  network_interface_id      = azurerm_network_interface.bootstrap_node.id
  network_security_group_id = azurerm_network_security_group.nodes.id
}

resource "azurerm_network_interface_security_group_association" "nodes" {
  for_each = local.topology

  network_interface_id      = azurerm_network_interface.nodes[each.key].id
  network_security_group_id = azurerm_network_security_group.nodes.id
}

resource "ssh_resource" "node_detail" {
  for_each = local.topology

  triggers = {
    revision = var.node_detail_revision
  }

  host         = azurerm_linux_virtual_machine.bootstrap_node.private_ip_address
  bastion_host = azurerm_linux_virtual_machine.bastion.public_ip_address
  bastion_port = 22

  user         = var.default_username
  bastion_user = var.default_username

  private_key         = tls_private_key.bastion_key.private_key_openssh
  bastion_private_key = tls_private_key.terraform_cloud.private_key_openssh

  commands = [
    "lxc cluster show ${azurerm_linux_virtual_machine.nodes[each.key].name}"
  ]
}

resource "terraform_data" "reboot" {
  for_each = local.topology

  input = {
    user                        = var.default_username
    node_name                   = azurerm_linux_virtual_machine.nodes[each.key].name
    bastion_private_key         = tls_private_key.bastion_key.private_key_openssh
    bastion_public_ip           = azurerm_linux_virtual_machine.bastion.public_ip_address
    bastion_port                = 22
    node_private_ip             = azurerm_linux_virtual_machine.nodes[each.key].private_ip_address
    terraform_cloud_private_key = tls_private_key.terraform_cloud.private_key_openssh
    commands = contains(yamldecode(ssh_resource.node_detail[each.key].result).roles, "database-leader") ? ["echo Node is database-leader restarting later", "sudo shutdown -r +1"] : [
      "sudo reboot"
    ]
  }

  connection {
    type                = "ssh"
    user                = self.input.user
    host                = self.input.node_private_ip
    private_key         = self.input.bastion_private_key
    bastion_user        = self.input.user
    bastion_host        = self.input.bastion_public_ip
    bastion_port        = self.input.bastion_port
    bastion_private_key = self.input.terraform_cloud_private_key
    timeout             = "10s"
  }

  provisioner "remote-exec" {
    on_failure = continue
    inline     = self.input.commands
  }
}

resource "terraform_data" "removal" {
  for_each = local.topology

  input = {
    user                        = var.default_username
    node_name                   = azurerm_linux_virtual_machine.nodes[each.key].name
    bastion_private_key         = tls_private_key.bastion_key.private_key_openssh
    bastion_public_ip           = azurerm_linux_virtual_machine.bastion.public_ip_address
    bastion_port                = 22
    bootstrap_node_private_ip   = azurerm_linux_virtual_machine.bootstrap_node.private_ip_address
    terraform_cloud_private_key = tls_private_key.terraform_cloud.private_key_openssh
    commands = contains(yamldecode(ssh_resource.node_detail[each.key].result).roles, "database-leader") ? [
      "echo ${var.protect_leader ? "Node is database-leader cannot destroy" : "Tearing it all down"}",
      "${var.protect_leader ? "exit 1" : "exit 0"}"
      ] : [
      "lxc cluster remove --force --yes ${azurerm_linux_virtual_machine.nodes[each.key].name}"
    ]
  }

  depends_on = [
    azurerm_linux_virtual_machine.bastion,
    azurerm_linux_virtual_machine.bootstrap_node,
    var.subnet_ids,
    var.virtual_network_id,
    azurerm_application_security_group.nodes,
    azurerm_network_security_group.nodes
  ]

  connection {
    type                = "ssh"
    user                = self.input.user
    host                = self.input.bootstrap_node_private_ip
    private_key         = self.input.bastion_private_key
    bastion_user        = self.input.user
    bastion_host        = self.input.bastion_public_ip
    bastion_port        = self.input.bastion_port
    bastion_private_key = self.input.terraform_cloud_private_key
    timeout             = "10s"
  }

  provisioner "remote-exec" {
    when   = destroy
    inline = self.input.commands
  }
}

module "balancer" {
  count = var.balancer ? 1 : 0

  source = "./modules/balancer"

  identifier         = var.identifier
  blueprint          = var.blueprint
  virtual_network_id = var.virtual_network_id
  resource_group = {
    name     = var.resource_group.name
    location = var.resource_group.location
  }

  bastion_node = {
    slug                 = azurerm_linux_virtual_machine.bastion.name
    id                   = azurerm_linux_virtual_machine.bastion.id
    public_ip            = azurerm_linux_virtual_machine.bastion.public_ip_address
    network_interface_id = azurerm_network_interface.bastion.id
  }

  bootstrap_node = {
    slug                 = azurerm_linux_virtual_machine.bootstrap_node.name
    id                   = azurerm_linux_virtual_machine.bootstrap_node.id
    public_ip            = azurerm_linux_virtual_machine.bootstrap_node.public_ip_address
    network_interface_id = azurerm_network_interface.bootstrap_node.id
  }

  nodes = [
    for key, node in azurerm_linux_virtual_machine.nodes :
    {
      slug                 = node.name
      public_ip            = node.public_ip_address
      id                   = node.id
      network_interface_id = azurerm_network_interface.nodes[key].id
    }
  ]
}