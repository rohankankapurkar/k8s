variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
}

variable "network_cidr" {
  description = "CIDR for the VPC network"
  type        = string
}

variable "subnet_cidr" {
  description = "CIDR for the subnet"
  type        = string
}
