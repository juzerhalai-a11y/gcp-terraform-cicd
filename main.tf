# Configure the Google Cloud Provider
provider "google" {
  project = "clgcporg10-19"
  region  = "us-central1"
}

# Define a resource: A Custom Virtual Private Cloud (VPC) Network
resource "google_compute_network" "vpc_network" {
  name                    = "ci-cd-managed-vpc"
  auto_create_subnetworks = true
}