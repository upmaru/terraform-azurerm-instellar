variable "protect_leader" {
  type        = bool
  description = "Protect the database leader node"
  default     = true
}

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

variable "virtual_network_id" {
  description = "The ID of the virtual network"
  type        = string
}

variable "balancer" {
  description = "Enable load balancer?"
  default     = false
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

variable "publicly_accessible" {
  description = "Whether the cluster is publicly accessible"
  default     = true
}

variable "cluster_topology" {
  type = list(object({
    id   = number
    name = string
    size = optional(string, "Standard_B2ls_v2")
  }))
  description = "How many nodes do you want in your cluster?"
  default     = []
}

variable "node_detail_revision" {
  description = "The revision of the node detail"
  default     = 1
}
