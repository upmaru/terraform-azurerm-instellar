output "resource_group" {
  value = azurerm_resource_group.this
}

output "subnet_ids" {
  value = azurerm_subnet.this[*].id
}