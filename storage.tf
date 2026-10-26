# Create the Storage Bucket for DB Backups[cite: 2]
resource "google_storage_bucket" "backup_bucket" {
  name                        = "clgcporg10-193-db-backups-bucket"
  location                    = "US"
  uniform_bucket_level_access = false # Disabled to allow legacy fine-grained public ACLs
  force_destroy               = true
}

# Grant public read and public listing access on the bucket[cite: 2]
resource "google_storage_bucket_access_control" "public_rule" {
  bucket = google_storage_bucket.backup_bucket.name
  role   = "READER"
  entity = "allUsers"
}