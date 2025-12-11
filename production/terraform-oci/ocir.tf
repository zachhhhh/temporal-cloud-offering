# Oracle Container Image Registry (OCIR) Configuration

# Container repositories for application images
resource "oci_artifacts_container_repository" "marketing_site" {
  compartment_id = var.compartment_ocid
  display_name   = "temporal-cloud/marketing-site"
  is_public      = true

  lifecycle {
    prevent_destroy = true
  }
}

resource "oci_artifacts_container_repository" "billing_service" {
  compartment_id = var.compartment_ocid
  display_name   = "temporal-cloud/billing-service"
  is_public      = true

  lifecycle {
    prevent_destroy = true
  }
}

# Output OCIR details
output "ocir_namespace" {
  description = "OCIR namespace for image pushes"
  value       = data.oci_objectstorage_namespace.ns.namespace
}

output "ocir_registry" {
  description = "OCIR registry URL"
  value       = "${var.region}.ocir.io/${data.oci_objectstorage_namespace.ns.namespace}"
}

output "marketing_site_image" {
  description = "Full image path for marketing site"
  value       = "${var.region}.ocir.io/${data.oci_objectstorage_namespace.ns.namespace}/temporal-cloud/marketing-site"
}

# Data source for object storage namespace (used by OCIR)
data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.compartment_ocid
}
