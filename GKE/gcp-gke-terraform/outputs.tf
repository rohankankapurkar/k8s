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
