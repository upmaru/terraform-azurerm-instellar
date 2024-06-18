locals {
  ssh_port = 2348
  topology = {
    for index, node in concat(var.nodes, [var.bootstrap_node]) :
    node.slug => node
  }
  ports = {
    http   = 80
    https  = 443
    uplink = 49152
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

resource "azurerm_lb_backend_address_pool" "nodes" {
  loadbalancer_id = azurerm_lb.this.id
  name            = "${var.identifier}-nodes-backend-pool"
}

resource "azurerm_lb_backend_address_pool" "lxd" {
  loadbalancer_id = azurerm_lb.this.id
  name            = "${var.identifier}-lxd-backend-pool"
}

resource "azurerm_lb_backend_address_pool" "bastion" {
  loadbalancer_id = azurerm_lb.this.id
  name            = "${var.identifier}-bastion-backend-pool"
}

resource "azurerm_network_interface_backend_address_pool_association" "bastion" {
  network_interface_id    = var.bastion_node.network_interface_id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.bastion.id
}

# resource "azurerm_network_interface_backend_address_pool_association" "nodes" {
#   for_each                = local.topology
#   network_interface_id    = each.value.network_interface_id
#   ip_configuration_name   = "internal"
#   backend_address_pool_id = azurerm_lb_backend_address_pool.nodes.id
# }

resource "azurerm_network_interface_backend_address_pool_association" "lxd" {
  for_each                = local.topology
  network_interface_id    = each.value.network_interface_id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lxd.id
}

resource "azurerm_lb_probe" "bastion" {
  loadbalancer_id = azurerm_lb.this.id
  name            = "ssh-probe"
  port            = 22
}

resource "azurerm_lb_probe" "lxd" {
  loadbalancer_id = azurerm_lb.this.id
  name            = "lxd-probe"
  port            = 8443
}

# resource "azurerm_lb_probe" "nodes" {
#   for_each = local.ports

#   loadbalancer_id = azurerm_lb.this.id
#   name            = "${each.key}-probe"
#   port            = each.value
# }

resource "azurerm_lb_rule" "bastion" {
  loadbalancer_id                = azurerm_lb.this.id
  name                           = "ssh-bastion-lb-rule"
  protocol                       = "Tcp"
  frontend_port                  = local.ssh_port
  backend_port                   = 22
  frontend_ip_configuration_name = "${var.identifier}-lb-frontend-ip"
  backend_address_pool_ids = [
    azurerm_lb_backend_address_pool.bastion.id
  ]
  probe_id              = azurerm_lb_probe.bastion.id
  disable_outbound_snat = true
}

resource "azurerm_lb_rule" "lxd" {
  loadbalancer_id                = azurerm_lb.this.id
  name                           = "lxd-nodes-lb-rule"
  protocol                       = "Tcp"
  frontend_port                  = 8443
  backend_port                   = 8443
  frontend_ip_configuration_name = "${var.identifier}-lb-frontend-ip"
  backend_address_pool_ids = [
    azurerm_lb_backend_address_pool.lxd.id
  ]
  probe_id              = azurerm_lb_probe.lxd.id
  disable_outbound_snat = true
}

# resource "azurerm_lb_rule" "nodes" {
#   for_each = local.ports

#   loadbalancer_id                = azurerm_lb.this.id
#   name                           = "${each.key}-nodes-lb-rule"
#   protocol                       = "Tcp"
#   frontend_port                  = each.value
#   backend_port                   = each.value
#   frontend_ip_configuration_name = "${var.identifier}-lb-frontend-ip"
#   backend_address_pool_ids = [
#     azurerm_lb_backend_address_pool.nodes.id
#   ]
#   probe_id              = azurerm_lb_probe.nodes[each.key].id
#   disable_outbound_snat = true
# }