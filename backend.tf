terraform {
  required_version = ">= 1.5.0"
  
  # This connects Terraform to your remote GCS backend
  backend "gcs" {
    bucket = "clgcporg10-193-terraform-state"
    prefix = "terraform/state"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}