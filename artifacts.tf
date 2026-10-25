resource "google_artifact_registry_repository" "my_repo" {
  location      = "us-central1"
  repository_id = "my-docker-repo"
  description   = "Docker repository for Wiz webapp exercise"
  format        = "DOCKER"
}