# Temporal Cloud - Oracle Cloud Infrastructure
# K3s Kubernetes Cluster with Free Tier Resources
#
# This Terraform configuration deploys:
# - K3s Kubernetes cluster (1 server + 2 workers on ARM)
# - Load balancer for ingress
# - Longhorn for persistent storage
# - Cert-manager for SSL
# - Nginx ingress controller
#
# Cost: $0/month (Oracle Always Free Tier)

terraform {
  required_version = ">= 1.0"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0"
    }
  }
}

# OCI Provider Configuration
provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}

# K3s Cluster Module
module "k3s_cluster" {
  source = "./k3s-oci-cluster"

  region                    = var.region
  availability_domain       = var.availability_domain
  tenancy_ocid              = var.tenancy_ocid
  compartment_ocid          = var.compartment_ocid
  my_public_ip_cidr         = var.my_public_ip_cidr
  cluster_name              = var.cluster_name
  environment               = var.environment
  os_image_id               = var.os_image_id
  certmanager_email_address = var.certmanager_email_address
  public_key_path           = var.public_key_path
  
  # Free tier limits: max 2 servers + 2 workers
  k3s_server_pool_size  = 1
  k3s_worker_pool_size  = 2
  k3s_extra_worker_node = false  # Stay within free tier
  
  # Ingress and SSL
  ingress_controller   = "nginx"
  install_certmanager  = true
  install_longhorn     = true
  install_argocd       = false  # Save resources
  
  # Expose kube API for remote kubectl
  expose_kubeapi = true
}

# Outputs
output "k3s_servers_ips" {
  description = "K3s server node IPs"
  value       = module.k3s_cluster.k3s_servers_ips
}

output "k3s_workers_ips" {
  description = "K3s worker node IPs"
  value       = module.k3s_cluster.k3s_workers_ips
}

output "public_lb_ip" {
  description = "Public load balancer IP for ingress"
  value       = module.k3s_cluster.public_lb_ip
}

output "kubeconfig_command" {
  description = "Command to get kubeconfig"
  value       = "scp -i ~/.ssh/oracle_temporal ubuntu@${module.k3s_cluster.k3s_servers_ips[0]}:/etc/rancher/k3s/k3s.yaml ~/.kube/config-oci"
}
