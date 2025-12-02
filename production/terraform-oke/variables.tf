# OKE Variables

variable "tenancy_ocid" {
  description = "OCI Tenancy OCID"
  type        = string
}

variable "user_ocid" {
  description = "OCI User OCID"
  type        = string
}

variable "fingerprint" {
  description = "OCI API Key Fingerprint"
  type        = string
}

variable "private_key_path" {
  description = "Path to OCI API private key"
  type        = string
}

variable "region" {
  description = "OCI Region"
  type        = string
  default     = "ap-singapore-1"
}

variable "compartment_ocid" {
  description = "OCI Compartment OCID"
  type        = string
}

variable "availability_domain" {
  description = "OCI Availability Domain"
  type        = string
}

variable "cluster_name" {
  description = "Name for the OKE cluster"
  type        = string
  default     = "temporal-cloud"
}

variable "kubernetes_version" {
  description = "Kubernetes version for OKE"
  type        = string
  default     = "v1.28.2" # Check OCI for latest supported
}

# Node configuration - optimized for Always Free tier
# Free tier: 4 OCPU + 24GB RAM total for ARM
variable "node_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2 # 2 nodes to distribute workload
}

variable "node_ocpus" {
  description = "OCPUs per node"
  type        = number
  default     = 2 # 2 OCPU x 2 nodes = 4 OCPU (free tier limit)
}

variable "node_memory_in_gbs" {
  description = "Memory per node in GB"
  type        = number
  default     = 12 # 12 GB x 2 nodes = 24 GB (free tier limit)
}

variable "node_image_id" {
  description = "OCID of the Oracle Linux image for nodes"
  type        = string
  # Oracle Linux 8 ARM image - update for your region
  # Find with: oci compute image list --compartment-id <compartment> --shape VM.Standard.A1.Flex
}
