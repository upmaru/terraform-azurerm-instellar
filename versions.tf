terraform {
  required_version = ">= 1.0.0"

  required_providers {
    ssh = {
      source = "loafoe/ssh"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}