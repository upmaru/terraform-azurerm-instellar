variable "identifier" {
  description = "Name of the cluster"
  type        = string
}

variable "blueprint" {
  description = "Name of the blueprint"
  type        = string
}

variable "resource_group" {
  description = "The resource group for the network"
}

variable "subnet_ids" {
  description = "List of subnets"
  default     = []
}

variable "bastion_size" {
  description = "The size of the bastion VM"
  default     = "Standard_B1s"
}

variable "default_username" {
  description = "The default username for the VMs"
  default     = "ubuntu"
}

variable "node_size" {
  description = "The size of the node VMs"
  default     = "Standard_B2ls_v2"
}

variable "address_space" {
  description = "Address space of the virtual network"
  type        = string
}

variable "storage_size" {
  description = "The size of the storage disks"
  default     = 40
}
