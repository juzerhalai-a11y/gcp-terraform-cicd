# Declare the project_id variable with your GCP project ID as the default value
variable "project_id" {
  type        = string
  description = "The GCP project ID"
  default     = "clgcporg10-193"
}

# 1. Detective Control: Enable Control Plane and Cloud Audit Logging for all services
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

# 2. Preventative Control: Enforce Public Access Prevention directly on Cloud Storage
resource "google_storage_bucket" "secure_bucket" {
  name                        = "${var.project_id}-secure-data-bucket"
  project                     = var.project_id
  location                    = "US"
  force_destroy               = true
  
  # Preventative Settings
  public_access_prevention    = "enforced"
  uniform_bucket_level_access = true
}