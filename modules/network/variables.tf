variable "identifier" {
  description = "Name of the network"
  type        = string
}

variable "blueprint" {
  description = "Name of the blueprint"
  type        = string
}

variable "region" {
  description = "Region of the resources"
  type        = string
}

variable "address_space" {
  description = "Address space of the virtual network"
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for the public subnets"
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
} 