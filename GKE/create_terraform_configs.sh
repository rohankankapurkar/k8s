#!/bin/bash

# Create directory structure
mkdir -p gcp-gke-terraform/modules/vpc
mkdir -p gcp-gke-terraform/modules/gke

# Root level files
cat > gcp-gke-terraform/main.tf << 'EOL'
provider "google" {
  project = var.project_id
  region  = var.region
}

terraform {
  backend "gcs" {
    bucket = "testing-gcp-backend"
    prefix = "terraform/state/gke"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

module "vpc" {
  source = "./modules/vpc"

  project_id    = var.project_id
  vpc_name      = var.vpc_name
  region        = var.region
  network_cidr  = var.network_cidr
  subnet_cidr   = var.subnet_cidr
}

module "gke" {
  source = "./modules/gke"

  project_id      = var.project_id
  region          = var.region
  cluster_name    = var.cluster_name
  vpc_id          = module.vpc.vpc_id
  subnet_id       = module.vpc.subnet_id
  node_pool_name  = var.node_pool_name
  node_count      = var.node_count
  machine_type    = var.machine_type
  disk_size_gb    = var.disk_size_gb
}
EOL

cat > gcp-gke-terraform/variables.tf << 'EOL'
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
  default     = 3
}

variable "machine_type" {
  description = "Machine type for the nodes"
  type        = string
  default     = "e2-medium"
}

variable "disk_size_gb" {
  description = "Disk size for the nodes in GB"
  type        = number
  default     = 100
}
EOL

cat > gcp-gke-terraform/outputs.tf << 'EOL'
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "subnet_id" {
  value = module.vpc.subnet_id
}

output "cluster_name" {
  value = module.gke.cluster_name
}

output "cluster_endpoint" {
  value = module.gke.cluster_endpoint
}
EOL

cat > gcp-gke-terraform/terraform.tfvars << 'EOL'
project_id = "indigo-lotus-445618-i0"
region     = "us-central1"
vpc_name   = "gke-vpc"
EOL

# VPC module files
cat > gcp-gke-terraform/modules/vpc/main.tf << 'EOL'
resource "google_compute_network" "vpc" {
  name                    = var.vpc_name
  auto_create_subnetworks = false
  project                 = var.project_id
}

resource "google_compute_subnetwork" "subnet" {
  name          = "${var.vpc_name}-subnet"
  project       = var.project_id
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc.id

  # Enable flow logs and private Google access
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling       = 0.5
    metadata           = "INCLUDE_ALL_METADATA"
  }
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pod-ranges"
    ip_cidr_range = "192.168.0.0/18"
  }

  secondary_ip_range {
    range_name    = "service-ranges"
    ip_cidr_range = "192.168.64.0/18"
  }
}

resource "google_compute_router" "router" {
  name    = "${var.vpc_name}-router"
  network = google_compute_network.vpc.id
  region  = var.region
  project = var.project_id
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.vpc_name}-nat"
  router                            = google_compute_router.router.name
  region                            = var.region
  project                           = var.project_id
  nat_ip_allocate_option           = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
EOL

cat > gcp-gke-terraform/modules/vpc/variables.tf << 'EOL'
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
EOL

cat > gcp-gke-terraform/modules/vpc/outputs.tf << 'EOL'
output "vpc_id" {
  value = google_compute_network.vpc.id
}

output "subnet_id" {
  value = google_compute_subnetwork.subnet.id
}
EOL

# GKE module files
cat > gcp-gke-terraform/modules/gke/main.tf << 'EOL'
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region
  project  = var.project_id

  remove_default_node_pool = true
  initial_node_count       = 1

  networking_mode = "VPC_NATIVE"
  network        = var.vpc_id
  subnetwork     = var.subnet_id

  ip_allocation_policy {
    cluster_secondary_range_name  = "pod-ranges"
    services_secondary_range_name = "service-ranges"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block = "172.16.0.0/28"
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "all"
    }
  }
}

resource "google_container_node_pool" "primary_nodes" {
  name       = var.node_pool_name
  location   = var.region
  cluster    = google_container_cluster.primary.name
  project    = var.project_id
  node_count = var.node_count

  node_config {
    machine_type = var.machine_type
    disk_size_gb = var.disk_size_gb

    oauth_scopes = [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/trace.append"
    ]
  }
}
EOL

cat > gcp-gke-terraform/modules/gke/variables.tf << 'EOL'
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet"
  type        = string
}

variable "node_pool_name" {
  description = "Name of the node pool"
  type        = string
}

variable "node_count" {
  description = "Number of nodes in the node pool"
  type        = number
}

variable "machine_type" {
  description = "Machine type for the nodes"
  type        = string
}

variable "disk_size_gb" {
  description = "Disk size for the nodes in GB"
  type        = number
}
EOL

cat > gcp-gke-terraform/modules/gke/outputs.tf << 'EOL'
output "cluster_name" {
  value = google_container_cluster.primary.name
}

output "cluster_endpoint" {
  value = google_container_cluster.primary.endpoint
}
EOL

echo "Terraform configuration files have been created in the gcp-gke-terraform directory"