resource "tls_private_key" "terraform_cloud" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_private_key" "bastion_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

data "azurerm_ssh_public_key" "user_key" {
  count = length(var.ssh_keys)

  name                = var.ssh_keys[count.index]
  resource_group_name = var.ssh_key_resource_group_name
} 