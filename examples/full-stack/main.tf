variable "identifier" {}
variable "blueprint" {}

variable "azure_region" {}
variable "azure_client_id" {}
variable "azure_client_secret" {}
variable "azure_subscription_id" {}
variable "azure_tenant_id" {}

provider "azurerm" {
  features {}

  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret
  tenant_id       = var.azure_tenant_id
  subscription_id = var.azure_subscription_id
}

module "networking_primary" {
  source = "../../modules/network"

  identifier = var.identifier
  blueprint  = var.blueprint
  region     = var.azure_region
}

module "compute_primary" {
  source = "../.."

  identifier = var.identifier
  blueprint  = var.blueprint

  resource_group = module.networking_primary.resource_group
  subnet_ids     = module.networking_primary.subnet_ids
}