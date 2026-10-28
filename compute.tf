# 1. Create an overly permissive Service Account (e.g., Editor role allowing VM creation)
resource "google_service_account" "overly_permissive_sa" {
  account_id   = "wiz-permissive-sa"
  display_name = "Overly Permissive Service Account for VM"
}

resource "google_project_iam_member" "vm_editor_role" {
  project = "clgcporg10-193"
  role    = "roles/editor" # Grants broad access including ability to create VMs
  member  = "serviceAccount:${google_service_account.overly_permissive_sa.email}"
}

# 2. Reserve a static internal IP address so it never changes on recreation
resource "google_compute_address" "mongodb_static_ip" {
  name         = "mongodb-internal-ip"
  subnetwork   = google_compute_subnetwork.public_subnet.id
  address_type = "INTERNAL"
  address      = "10.0.1.16" # Locks the IP to your exact address
}

# 3. Create the Virtual Machine running Debian 12 (Bookworm)
resource "google_compute_instance" "mongodb_vm" {
  name         = "wiz-mongodb-server"
  machine_type = "e2-medium"
  zone         = "us-central1-a"

  # Applies network tags matching the firewall rules defined in network.tf
  tags = ["public-vm", "mongodb-vm"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12" 
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.public_subnet.id
    
    # Force the VM to always use this exact internal IP
    network_ip = google_compute_address.mongodb_static_ip.address
    
    # Ephemeral public IP to expose SSH to the public internet
    access_config {
      network_tier = "STANDARD"
    }
  }

  service_account {
    email  = google_service_account.overly_permissive_sa.email
    scopes = ["cloud-platform"]
  }

  # Startup script using native MongoDB 7.0 repository for Debian 12
  metadata_startup_script = <<-EOT
    #!/bin/bash
    export DEBIAN_FRONTEND=noninteractive

    # 1. Install prerequisites
    apt-get update
    apt-get install -y gnupg curl

    # 2. Add MongoDB 7.0 GPG key and repository for Debian 12 (Bookworm)
    curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg
    echo "deb [signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg] http://repo.mongodb.org/apt/debian bookworm/mongodb-org/7.0 main" | tee /etc/apt/sources.list.d/mongodb-org-7.0.list

    # 3. Update and install mongodb-org natively
    apt-get update
    apt-get install -y mongodb-org

    # 4. Configure MongoDB to listen on all interfaces (Auth disabled)
    cat << 'EOF' > /etc/mongod.conf
storage:
  dbPath: /var/lib/mongodb
systemLog:
  destination: file
  path: /var/log/mongodb/mongod.log
  logAppend: true
net:
  bindIp: 0.0.0.0
  port: 27017
EOF

    # 5. Start and enable service natively
    systemctl daemon-reload
    systemctl start mongod
    systemctl enable mongod

    # Create Automated Daily Backup Script targeting the public storage bucket
    cat << 'MONGO_EOF' > /usr/local/bin/mongo_backup.sh
#!/bin/bash
TIMESTAMP=\$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/tmp/mongo_backup_\$TIMESTAMP"
mkdir -p \$BACKUP_DIR
mongodump --out \$BACKUP_DIR
tar -zcvf $${BACKUP_DIR}.tar.gz -C /tmp/ "mongo_backup_$TIMESTAMP"
gsutil cp $${BACKUP_DIR}.tar.gz gs://${google_storage_bucket.backup_bucket.name}/
rm -rf \$BACKUP_DIR $${BACKUP_DIR}.tar.gz
MONGO_EOF
    chmod +x /usr/local/bin/mongo_backup.sh

    # Setup Cron job for daily automated backup execution
    (crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/mongo_backup.sh") | crontab -
  EOT
}