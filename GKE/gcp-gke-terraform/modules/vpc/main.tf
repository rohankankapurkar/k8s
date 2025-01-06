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
