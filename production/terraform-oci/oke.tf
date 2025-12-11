# Oracle Kubernetes Engine (OKE) Configuration
# This file manages the OKE cluster that was created via console

# Data source for existing OKE cluster
data "oci_containerengine_clusters" "existing" {
  compartment_id = var.compartment_ocid
  name           = "temporal-cloud-oke"
}

data "oci_containerengine_cluster_kube_config" "oke_kubeconfig" {
  count      = length(data.oci_containerengine_clusters.existing.clusters) > 0 ? 1 : 0
  cluster_id = data.oci_containerengine_clusters.existing.clusters[0].id
}

# Output OKE cluster details
output "oke_cluster_id" {
  description = "OKE cluster OCID"
  value       = length(data.oci_containerengine_clusters.existing.clusters) > 0 ? data.oci_containerengine_clusters.existing.clusters[0].id : null
}

output "oke_cluster_endpoint" {
  description = "OKE cluster Kubernetes API endpoint"
  value       = length(data.oci_containerengine_clusters.existing.clusters) > 0 ? data.oci_containerengine_clusters.existing.clusters[0].endpoints[0].public_endpoint : null
}

output "oke_kubeconfig_command" {
  description = "Command to get OKE kubeconfig"
  value       = length(data.oci_containerengine_clusters.existing.clusters) > 0 ? "oci ce cluster create-kubeconfig --cluster-id ${data.oci_containerengine_clusters.existing.clusters[0].id} --file ~/.kube/config-oke --overwrite" : null
}
