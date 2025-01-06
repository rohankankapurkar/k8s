variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "indigo-lotus-445618-i0"
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
  default     = "gke-vpc"
}

variable "network_cidr" {
  description = "CIDR for the VPC network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR for the subnet"
  type        = string
  default     = "10.0.0.0/20"
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "my-gke-cluster"
}

variable "node_pool_name" {
  description = "Name of the node pool"
  type        = string
  default     = "primary-node-pool"
}

variable "node_count" {
  description = "Number of nodes in the node pool"
  type        = number
  default     = 1
}

variable "machine_type" {
  description = "Machine type for the nodes"
  type        = string
  default     = "e2-medium"
}

variable "disk_size_gb" {
  description = "Disk size for the nodes in GB"
  type        = number
  default     = 10
}
