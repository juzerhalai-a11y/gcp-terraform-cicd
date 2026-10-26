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

# 2. Create the Virtual Machine running Debian 11 for native MongoDB compatibility
resource "google_compute_instance" "mongodb_vm" {
  name         = "wiz-mongodb-server"
  machine_type = "e2-medium"
  zone         = "us-central1-a"

  # Applies network tags matching the firewall rules defined in network.tf
  tags = ["public-vm", "mongodb-vm"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11" 
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.public_subnet.id
    
    # Ephemeral public IP to expose SSH to the public internet
    access_config {
      network_tier = "STANDARD"
    }
  }

  service_account {
    email  = google_service_account.overly_permissive_sa.email
    scopes = ["cloud-platform"]
  }

  # Startup script to install MongoDB natively on Debian 11 and configure backups
  metadata_startup_script = <<-EOT
    #!/bin/bash
    export DEBIAN_FRONTEND=noninteractive

    apt-get update
    apt-get install -y gnupg wget curl

    # Install MongoDB 4.4 natively on Debian 11 (Bullseye)
    wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | apt-key add -
    echo "deb http://repo.mongodb.org/apt/debian bullseye/mongodb-org/4.4 main" | tee /etc/apt/sources.list.d/mongodb-org-4.4.list
    apt-get update
    apt-get install -y mongodb-org=4.4.18 mongodb-org-server=4.4.18 mongodb-org-shell=4.4.18 mongodb-org-mongos=4.4.18 mongodb-org-tools=4.4.18

    # Configure MongoDB to require database authentication
    sed -i 's/#security:/security:\n  authorization: "enabled"/' /etc/mongod.conf

    # Allow external network connections from your GKE private cluster subnet
    sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/g' /etc/mongod.conf

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
    rm -rf $${BACKUP_DIR} $${BACKUP_DIR}.tar.gz
    MONGO_EOF
    chmod +x /usr/local/bin/mongo_backup.sh

    # Setup Cron job for daily automated backup execution
    (crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/mongo_backup.sh") | crontab -
  EOT
}