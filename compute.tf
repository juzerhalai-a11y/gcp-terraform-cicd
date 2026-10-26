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

# 2. Create the Virtual Machine running Debian 12
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
    
    # Ephemeral public IP to expose SSH to the public internet
    access_config {
      network_tier = "STANDARD"
    }
  }

  service_account {
    email  = google_service_account.overly_permissive_sa.email
    scopes = ["cloud-platform"]
  }

  # Startup script using MongoDB 4.4 binary tarball for Debian 12 compatibility
  metadata_startup_script = <<-EOT
    #!/bin/bash
    export DEBIAN_FRONTEND=noninteractive

    apt-get update
    apt-get install -y wget curl libgomp1

    # Download and extract MongoDB 4.4 official binaries directly (bypasses apt libssl dependencies)
    wget https://downloads.mongodb.org/linux/mongodb-linux-x86_64-debian10-4.4.18.tgz
    tar -zxvf mongodb-linux-x86_64-debian10-4.4.18.tgz
    mv mongodb-linux-x86_64-debian10-4.4.18 /opt/mongodb

    # Create MongoDB data and log directories
    mkdir -p /var/lib/mongo /var/log/mongodb
    useradd -r -s /bin/false mongodb || true
    chown -R mongodb:mongodb /var/lib/mongo /var/log/mongodb

    # Create standard configuration file
    cat << 'EOF' > /etc/mongod.conf
    storage:
      dbPath: /var/lib/mongo
    systemLog:
      destination: file
      path: /var/log/mongodb/mongod.log
      logAppend: true
    net:
      bindIp: 0.0.0.0
      port: 27017
    security:
      authorization: "enabled"
    EOF

    chown mongodb:mongodb /etc/mongod.conf

    # Create systemd service for MongoDB
    cat << 'EOF' > /etc/systemd/system/mongod.service
    [Unit]
    Description=MongoDB Database Server
    Documentation=https://docs.mongodb.org/manual
    After=network.target

    [Service]
    User=mongodb
    Group=mongodb
    ExecStart=/opt/mongodb/bin/mongod --config /etc/mongod.conf
    Restart=always
    LimitFSIZE=infinity
    LimitCPU=infinity
    LimitAS=infinity
    LimitMEMLOCK=infinity
    TasksMax=infinity
    TasksAccounting=false

    [Install]
    WantedBy=multi-user.target
    EOF

    systemctl daemon-reload
    systemctl start mongod
    systemctl enable mongod

    # Create Automated Daily Backup Script targeting the public storage bucket
    cat << 'MONGO_EOF' > /usr/local/bin/mongo_backup.sh
    #!/bin/bash
    TIMESTAMP=\$(date +%Y%m%d_%H%M%S)
    BACKUP_DIR="/tmp/mongo_backup_\$TIMESTAMP"
    mkdir -p \$BACKUP_DIR
    /opt/mongodb/bin/mongodump --out \$BACKUP_DIR
    tar -zcvf $${BACKUP_DIR}.tar.gz -C /tmp/ "mongo_backup_$TIMESTAMP"
    gsutil cp $${BACKUP_DIR}.tar.gz gs://${google_storage_bucket.backup_bucket.name}/
    rm -rf $${BACKUP_DIR} $${BACKUP_DIR}.tar.gz
    MONGO_EOF
    chmod +x /usr/local/bin/mongo_backup.sh

    # Setup Cron job for daily automated backup execution
    (crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/mongo_backup.sh") | crontab -
  EOT
}