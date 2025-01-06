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

resource "google_container_node_pool" "pool-1" {
  name       = "pool-1"
  location   = "us-central1"
  cluster    = module.gke.cluster_name
  version    = "1.30.6-gke.1125000"

  initial_node_count = 1

  node_locations = [
    "us-central1-a",
    "us-central1-f",
    "us-central1-b"
  ]

  network_config {
    enable_private_nodes = true
    pod_range           = "pod-ranges"
    # Removed pod_ipv4_cidr_block as it requires create_pod_range to be true
  }

  node_config {
    machine_type = "e2-medium"
    disk_size_gb = 100
    disk_type    = "pd-balanced"
    image_type   = "COS_CONTAINERD"

    oauth_scopes = [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/trace.append"
    ]

    metadata = {
      "disable-legacy-endpoints" = "true"
    }

    service_account = "default"

    shielded_instance_config {
      enable_integrity_monitoring = true
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge = 1
    strategy  = "SURGE"
  }
}