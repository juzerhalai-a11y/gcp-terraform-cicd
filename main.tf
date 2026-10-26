# Configure the Google Cloud Provider
provider "google" {
  project = "clgcporg10-193"
  region  = "us-central1"
}

# Define a resource: A Custom Virtual Private Cloud (VPC) Network
resource "google_compute_network" "vpc_network" {
  name                    = "wiz-exercise-vpc"
  auto_create_subnetworks = true
}

# Define the firewall rule for MongoDB traffic
resource "google_compute_firewall" "allow_mongodb" {
  name        = "allow-mongodb-27017"
  network     = google_compute_network.vpc_network.name
  direction   = "INGRESS"
  description = "Allow incoming MongoDB traffic on port 27017"

  allow {
    protocol = "tcp"
    ports    = ["27017"]
  }

  source_ranges = ["0.0.0.0/0"]
}