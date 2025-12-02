# Oracle Kubernetes Engine (OKE) with Free Tier Resources
# Uses $300 credits initially, then transitions to Always Free tier

terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 5.0"
    }
  }
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}

# VCN for OKE
resource "oci_core_vcn" "oke_vcn" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.cluster_name}-vcn"
  cidr_blocks    = ["10.0.0.0/16"]
  dns_label      = "okecluster"
}

# Internet Gateway
resource "oci_core_internet_gateway" "oke_igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.oke_vcn.id
  display_name   = "${var.cluster_name}-igw"
  enabled        = true
}

# NAT Gateway (for private nodes)
resource "oci_core_nat_gateway" "oke_nat" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.oke_vcn.id
  display_name   = "${var.cluster_name}-nat"
}

# Route Table for Public Subnet
resource "oci_core_route_table" "oke_public_rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.oke_vcn.id
  display_name   = "${var.cluster_name}-public-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.oke_igw.id
  }
}

# Route Table for Private Subnet
resource "oci_core_route_table" "oke_private_rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.oke_vcn.id
  display_name   = "${var.cluster_name}-private-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.oke_nat.id
  }
}

# Security List for API Endpoint
resource "oci_core_security_list" "oke_api_sl" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.oke_vcn.id
  display_name   = "${var.cluster_name}-api-sl"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 6443
      max = 6443
    }
  }
}

# Security List for Worker Nodes
resource "oci_core_security_list" "oke_worker_sl" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.oke_vcn.id
  display_name   = "${var.cluster_name}-worker-sl"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  # Allow all traffic within VCN
  ingress_security_rules {
    protocol = "all"
    source   = "10.0.0.0/16"
  }

  # Allow NodePort services
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 30000
      max = 32767
    }
  }

  # Allow HTTP/HTTPS
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 80
      max = 80
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 443
      max = 443
    }
  }
}

# Public Subnet for Load Balancers
resource "oci_core_subnet" "oke_lb_subnet" {
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.oke_vcn.id
  display_name      = "${var.cluster_name}-lb-subnet"
  cidr_block        = "10.0.20.0/24"
  route_table_id    = oci_core_route_table.oke_public_rt.id
  security_list_ids = [oci_core_security_list.oke_api_sl.id]
  dns_label         = "lbsubnet"
}

# Public Subnet for API Endpoint
resource "oci_core_subnet" "oke_api_subnet" {
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.oke_vcn.id
  display_name      = "${var.cluster_name}-api-subnet"
  cidr_block        = "10.0.0.0/24"
  route_table_id    = oci_core_route_table.oke_public_rt.id
  security_list_ids = [oci_core_security_list.oke_api_sl.id]
  dns_label         = "apisubnet"
}

# Private Subnet for Worker Nodes
resource "oci_core_subnet" "oke_worker_subnet" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.oke_vcn.id
  display_name               = "${var.cluster_name}-worker-subnet"
  cidr_block                 = "10.0.10.0/24"
  route_table_id             = oci_core_route_table.oke_private_rt.id
  security_list_ids          = [oci_core_security_list.oke_worker_sl.id]
  prohibit_public_ip_on_vnic = true
  dns_label                  = "workersubnet"
}

# OKE Cluster (Control Plane is FREE!)
resource "oci_containerengine_cluster" "oke_cluster" {
  compartment_id     = var.compartment_ocid
  kubernetes_version = var.kubernetes_version
  name               = var.cluster_name
  vcn_id             = oci_core_vcn.oke_vcn.id

  endpoint_config {
    is_public_ip_enabled = true
    subnet_id            = oci_core_subnet.oke_api_subnet.id
  }

  options {
    service_lb_subnet_ids = [oci_core_subnet.oke_lb_subnet.id]

    add_ons {
      is_kubernetes_dashboard_enabled = false
      is_tiller_enabled               = false
    }

    kubernetes_network_config {
      pods_cidr     = "10.244.0.0/16"
      services_cidr = "10.96.0.0/16"
    }
  }

  type = "BASIC_CLUSTER" # Free tier compatible
}

# Node Pool with ARM instances (Always Free eligible)
resource "oci_containerengine_node_pool" "oke_node_pool" {
  cluster_id         = oci_containerengine_cluster.oke_cluster.id
  compartment_id     = var.compartment_ocid
  kubernetes_version = var.kubernetes_version
  name               = "${var.cluster_name}-pool"

  node_shape = "VM.Standard.E4.Flex" # x86 - Uses $300 credits

  node_shape_config {
    ocpus         = var.node_ocpus         # 2 OCPU per node (4 total free)
    memory_in_gbs = var.node_memory_in_gbs # 12 GB per node (24 total free)
  }

  node_config_details {
    size = var.node_count # 2 nodes to use full free tier

    placement_configs {
      availability_domain = var.availability_domain
      subnet_id           = oci_core_subnet.oke_worker_subnet.id
    }
  }

  node_source_details {
    image_id    = var.node_image_id
    source_type = "IMAGE"
  }

  initial_node_labels {
    key   = "name"
    value = var.cluster_name
  }
}

# Outputs
output "cluster_id" {
  value = oci_containerengine_cluster.oke_cluster.id
}

output "cluster_endpoint" {
  value = oci_containerengine_cluster.oke_cluster.endpoints[0].public_endpoint
}

output "kubeconfig_command" {
  value = "oci ce cluster create-kubeconfig --cluster-id ${oci_containerengine_cluster.oke_cluster.id} --file ~/.kube/config --region ${var.region} --token-version 2.0.0"
}

output "node_pool_id" {
  value = oci_containerengine_node_pool.oke_node_pool.id
}
