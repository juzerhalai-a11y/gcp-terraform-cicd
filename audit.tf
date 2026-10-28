# Declare the project_id variable so Terraform recognizes it across the configuration scope
variable "project_id" {
  type        = string
  description = "The GCP project ID"
}

# Enable Control Plane and Cloud Audit Logging for all services
resource "google_project_iam_audit_config" "project_audit" {
  project = var.project_id
  service = "allServices"

  audit_log_config {
    log_type = "ADMIN_READ"
  }
  audit_log_config {
    log_type = "DATA_READ"
  }
  audit_log_config {
    log_type = "DATA_WRITE"
  }
}