resource "azurerm_resource_group" "this" {
  name     = var.identifier
  location = var.region
}

resource "azurerm_virtual_network" "this" {
  name                = "${var.identifier}-vnet"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  address_space = var.address_space

  tags = {
    blueprint = var.blueprint
  }
}

resource "azurerm_subnet" "this" {
  count                = length(var.public_subnet_cidrs)
  name                 = "${var.identifier}-public-${count.index}"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name

  address_prefixes = [var.public_subnet_cidrs[count.index]]
}