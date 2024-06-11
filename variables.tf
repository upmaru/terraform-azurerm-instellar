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

variable "ssh_keys" {
  description = "List of SSH public keys"
  type        = list(string)
}

variable "ssh_key_resource_group_name" {
  description = "The resource group for the SSH keys"
  type        = string
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

variable "bastion_ssh" {
  description = "Whether to allow SSH to the bastion"
  default     = true
}
