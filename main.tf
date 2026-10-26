# Configure the Google Cloud Provider
provider "google" {
  project = "clgcporg10-193"
  region  = "us-central1"
}

# Fetch current GCP client config for authentication tokens
data "google_client_config" "default" {}

# Configure the Kubernetes Provider using data sources from the GKE cluster
provider "kubernetes" {
  host                   = "https://${google_container_cluster.private_cluster.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.private_cluster.master_auth[0].cluster_ca_certificate)
}