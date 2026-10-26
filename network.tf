# 1. Create a custom VPC Network
resource "google_compute_network" "vpc_network" {
  name                    = "wiz-exercise-vpc"
  auto_create_subnetworks = false
}

# 2. Create the Public Subnet (for the VM running MongoDB)
resource "google_compute_subnetwork" "public_subnet" {
  name          = "wiz-public-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = "us-central1"
  network       = google_compute_network.vpc_network.name

  lifecycle {
    create_before_destroy = true
  }
}

# 3. Create the Private Subnet (for the K8s Cluster)
resource "google_compute_subnetwork" "private_subnet" {
  name          = "wiz-private-subnet"
  ip_cidr_range = "10.0.2.0/24"
  region        = "us-central1"
  network       = google_compute_network.vpc_network.name

  lifecycle {
    create_before_destroy = true
  }
}

# 4. Firewall Rule: Expose SSH to the Public Internet
resource "google_compute_firewall" "allow_public_ssh" {
  name    = "allow-ssh-public"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["public-vm"]
}

# 5. Firewall Rule: Restrict MongoDB Access to Kubernetes Network Only
resource "google_compute_firewall" "allow_k8s_to_mongo" {
  name    = "allow-k8s-to-mongodb"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["27017"] # Standard MongoDB port
  }

  # Restricts database access exclusively to the private subnet where K8s runs
  source_ranges = [google_compute_subnetwork.private_subnet.ip_cidr_range]
  target_tags   = ["mongodb-vm"]
}