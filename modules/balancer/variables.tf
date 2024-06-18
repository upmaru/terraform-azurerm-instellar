variable "ssh" {
  description = "Enable SSH?"
  default     = true
}

variable "blueprint" {
  description = "Name of the blueprint"
  type        = string
}

variable "identifier" {
  description = "Name of the cluster"
  type        = string
}

variable "virtual_network_id" {
  description = "The ID of the virtual network"
  type        = string
}

variable "bastion_node" {
  description = "The bastion node"
  type = object({
    id                   = string
    slug                 = string
    public_ip            = string
    network_interface_id = string
  })
}

variable "bootstrap_node" {
  description = "The bootstrap node"
  type = object({
    id                   = string
    slug                 = string
    public_ip            = string
    network_interface_id = string
  })
}

variable "nodes" {
  description = "The nodes of the cluster"
  type = list(object({
    id                   = string
    slug                 = string
    public_ip            = string
    network_interface_id = string
  }))
}

variable "resource_group" {
  description = "The resource group for the network"
  type = object({
    name     = string
    location = string
  })
}