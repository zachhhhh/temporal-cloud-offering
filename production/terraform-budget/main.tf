# OCI Budget and Cost Control
# Ensures spending stops after $300 credits are used

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

variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}
variable "region" { default = "ap-singapore-1" }
variable "compartment_ocid" {}
variable "budget_amount" { default = 290 }  # $290 to leave buffer
variable "alert_threshold" { default = 80 }  # Alert at 80%

# Budget to track spending
resource "oci_budget_budget" "temporal_budget" {
  compartment_id = var.tenancy_ocid
  amount         = var.budget_amount
  reset_period   = "MONTHLY"
  target_type    = "COMPARTMENT"
  targets        = [var.compartment_ocid]
  display_name   = "temporal-cloud-budget"
  description    = "Budget for Temporal Cloud - Stop at $300"

  # Budget processing is SINGLE_USE for one-time credits
  processing_period_type = "SINGLE_USE"
}

# Alert rule at 80% ($240)
resource "oci_budget_alert_rule" "alert_80" {
  budget_id      = oci_budget_budget.temporal_budget.id
  type           = "ACTUAL"
  threshold      = 80
  threshold_type = "PERCENTAGE"
  display_name   = "80% Budget Alert"
  message        = "WARNING: Temporal Cloud has used 80% of $300 credits ($240)"
  recipients     = var.alert_email
}

# Alert rule at 95% ($285)
resource "oci_budget_alert_rule" "alert_95" {
  budget_id      = oci_budget_budget.temporal_budget.id
  type           = "ACTUAL"
  threshold      = 95
  threshold_type = "PERCENTAGE"
  display_name   = "95% Budget Alert"
  message        = "CRITICAL: Temporal Cloud has used 95% of $300 credits ($285). Scaling down resources."
  recipients     = var.alert_email
}

# Alert rule at 100%
resource "oci_budget_alert_rule" "alert_100" {
  budget_id      = oci_budget_budget.temporal_budget.id
  type           = "ACTUAL"
  threshold      = 100
  threshold_type = "PERCENTAGE"
  display_name   = "100% Budget Alert"
  message        = "STOP: Temporal Cloud has exhausted $300 credits. All resources will be stopped."
  recipients     = var.alert_email
}

variable "alert_email" {
  type    = string
  default = "admin@yourdomain.com"
}

output "budget_id" {
  value = oci_budget_budget.temporal_budget.id
}
