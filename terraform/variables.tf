### Variables

variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}
variable "compartment_ocid" {}
variable "ssh_public_key_path" {}
variable "ssh_private_key_path" {}
variable "docker_registry_location_path" {}
variable "chef_server_url" {}
variable "chef_username" {}
variable "chef_private_key" {}
variable "region" {default="us-ashburn-1"}
variable "identifier" {default="local"}
variable "ad" {default="1"}

variable "VPC-CIDR" {
  default = "10.0.0.0/16"
}

variable "InstanceOS" {
    default = "CentOS"
}

variable "InstanceOSVersion" {
    default = "7"
}
