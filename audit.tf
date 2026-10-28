# Declare the project_id variable with your GCP project ID as the default value
variable "project_id" {
  type        = string
  description = "The GCP project ID"
  default     = "clgcporg10-193"
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
# Preventative Control: Enforce Public Access Prevention on Cloud Storage
resource "google_project_organization_policy" "enforce_bucket_public_access" {
  project    = var.project_id
  constraint = "storage.publicAccessPrevention"

  boolean_policy {
    enforced = true
  }
}