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

  balancer                    = true
  resource_group              = module.networking_primary.resource_group
  subnet_ids                  = module.networking_primary.subnet_ids
  virtual_network_id          = module.networking_primary.virtual_network_id
  address_space               = module.networking_primary.address_space
  ssh_keys                    = ["zack-studio"]
  ssh_key_resource_group_name = "opsmaru"
  cluster_topology = [
    { id = 1, name = "01", size = "Standard_B2ls_v2" },
    { id = 2, name = "02", size = "Standard_B2ls_v2" }
  ]
  storage_size = 40
}