# 1. Private GKE Cluster Deployed in the Custom VPC Network
resource "google_container_cluster" "private_cluster" {
  name     = "wiz-private-k8s-cluster"
  location = "us-central1-a"

  # We can't create a cluster with no node pool defined, but we want to manage it separately
  remove_default_node_pool = true
  initial_node_count        = 1

  network    = google_compute_network.vpc_network.name
  subnetwork = google_compute_subnetwork.private_subnet.name # Fixed to use your custom private subnet

  # Enforce Private Cluster Settings (nodes only have private IPs)
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  ip_allocation_policy {
    cluster_ipv4_cidr_block  = "10.16.0.0/16"
    services_ipv4_cidr_block = "10.17.0.0/16"
  }

  deletion_protection = false
}

# 2. Managed Node Pool for the Private Cluster
resource "google_container_node_pool" "primary_nodes" {
  name       = "wiz-node-pool"
  location   = "us-central1-a"
  cluster    = google_container_cluster.private_cluster.name
  node_count = 1

  node_config {
    machine_type = "e2-medium"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

# 3. Kubernetes Service Account for the Container Application
resource "kubernetes_service_account" "app_sa" {
  metadata {
    name      = "webapp-service-account"
    namespace = "default"
  }
}

# 4. Cluster-Wide Kubernetes Admin Role Binding (Assigns cluster-admin privilege)
resource "kubernetes_cluster_role_binding" "app_admin_binding" {
  metadata {
    name = "app-cluster-admin-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin" # Grants full cluster-wide admin rights
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.app_sa.metadata[0].name
    namespace = "default"
  }
}

# 5. Containerized Application Deployment (Injecting MongoDB via Environment Variable)
resource "kubernetes_deployment" "webapp" {
  metadata {
    name = "webapp-deployment"
    labels = {
      app = "todo-webapp"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "todo-webapp"
      }
    }

    template {
      metadata {
        labels = {
          app = "todo-webapp"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.app_sa.metadata[0].name

        container {
          image = "${google_artifact_registry_repository.my_repo.location}-docker.pkg.dev/${google_artifact_registry_repository.my_repo.project}/${google_artifact_registry_repository.my_repo.name}/webapp:latest"
          name              = "webapp"
          image_pull_policy = "Always"

          port {
            container_port = 8080
          }

          env {
            name  = "MONGODB_URI"
            value = "mongodb://10.0.1.16:27017/todo"
          }
        }
      }
    }
  }
}

# 6. Kubernetes Service to bundle application pods internally
resource "kubernetes_service" "webapp_service" {
  metadata {
    name = "webapp-service"
  }
  spec {
    selector = {
      app = "todo-webapp" 
    }
    port {
      port        = 80
      target_port = 8080
    }
    type = "NodePort"
  }
}

# 7. Kubernetes Ingress (Dynamically provisions the Cloud Provider Load Balancer)
resource "kubernetes_ingress_v1" "webapp_ingress" {
  metadata {
    name = "webapp-ingress"
    annotations = {
      "kubernetes.io/ingress.class" = "gce" # Triggers GCP external HTTP(S) Load Balancer creation
    }
  }

  spec {
    default_backend {
      service {
        name = kubernetes_service.webapp_service.metadata[0].name
        port {
          number = 80
        }
      }
    }
  }
}