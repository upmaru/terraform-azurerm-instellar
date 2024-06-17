locals {
  ssh_port = 2348
  topology = {
    for index, node in concat(var.nodes, [var.bootstrap_node]) :
    node.slug => node
  }
}

resource "azurerm_public_ip" "this" {
  name                = "${var.identifier}-balancer-public-ip"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    blueprint = var.blueprint
  }
}

resource "azurerm_lb" "this" {
  name                = "${var.identifier}-lb"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "${var.identifier}-lb-frontend-ip"
    public_ip_address_id = azurerm_public_ip.this.id
  }

  tags = {
    blueprint = var.blueprint
  }
}

resource "azurerm_lb_backend_address_pool" "this" {
  loadbalancer_id = azurerm_lb.this.id
  name            = "${var.identifier}-backend-address-pool"
}

resource "azurerm_network_interface_backend_address_pool_association" "nodes" {
  for_each                = local.topology
  network_interface_id    = each.value.network_interface_id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.this.id
}

resource "azurerm_lb_probe" "ssh" {
  loadbalancer_id = azurerm_lb.this.id
  name            = "ssh-probe"
  port            = 22
}

resource "azurerm_lb_probe" "http" {
  loadbalancer_id = azurerm_lb.this.id
  name            = "http-probe"
  port            = 80
}

resource "azurerm_lb_probe" "https" {
  loadbalancer_id = azurerm_lb.this.id
  name            = "https-probe"
  port            = 443
}

resource "azurerm_lb_probe" "lxd" {
  loadbalancer_id = azurerm_lb.this.id
  name            = "lxd-probe"
  port            = 8443
}

resource "azurerm_lb_probe" "uplink" {
  loadbalancer_id = azurerm_lb.this.id
  name            = "uplink-probe"
  port            = 49152
}