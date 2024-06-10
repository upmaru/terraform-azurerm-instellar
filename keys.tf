resource "tls_private_key" "terraform_cloud" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_private_key" "bastion_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}