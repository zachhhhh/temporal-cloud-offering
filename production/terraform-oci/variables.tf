# Oracle Cloud Infrastructure Variables

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
  default     = "~/.oci/oci_api_key.pem"
}

variable "region" {
  description = "OCI Region"
  type        = string
  default     = "ap-singapore-1"
}

variable "compartment_ocid" {
  description = "OCI Compartment OCID (use tenancy OCID for root compartment)"
  type        = string
}

variable "availability_domain" {
  description = "OCI Availability Domain"
  type        = string
}

variable "cluster_name" {
  description = "Name for the K3s cluster"
  type        = string
  default     = "temporal-cloud"
}

variable "environment" {
  description = "Environment name (staging/production)"
  type        = string
  default     = "production"
}

variable "os_image_id" {
  description = "OCI Image OCID for ARM instances"
  type        = string
}

variable "my_public_ip_cidr" {
  description = "Your public IP in CIDR format for SSH access"
  type        = string
}

variable "certmanager_email_address" {
  description = "Email for Let's Encrypt certificates"
  type        = string
}

variable "public_key_path" {
  description = "Path to SSH public key for instance access"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}
