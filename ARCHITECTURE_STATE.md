# Architecture & Deployment State (Saved)

## 1. Core Infrastructure & IPs
- **MongoDB VM:** `wiz-mongodb-server` (Internal IP: `10.0.1.11`, Zone: `us-central1-a`)
- **MongoDB Configuration:** Listening on `0.0.0.0:27017` with binaries at `/opt/mongodb`.
- **GKE Cluster:** `wiz-private-k8s-cluster` in `us-central1-a`.
- **Web App Service:** `webapp-deployment` running Go / Gin application container.
- **External Load Balancer IP:** `34.8.145.12`

## 2. Identified Root Causes & Fixes Applied
- **IP Mismatch:** Updated `k8s.tf` so `MONGODB_URI` points to `mongodb://10.0.1.11:27017/todo`.
- **Dependencies & Service:** Verified `mongod.service` is active and running on Debian 12 using MongoDB 4.4 binaries.
- **Firewall & Tags:** `network.tf` defines `allow-k8s-to-mongodb` targeting `mongodb-vm` from subnet `10.0.2.0/24`.

## 3. Current Symptom
- Pod logs show `dial tcp 10.0.1.11:27017: i/o timeout` when hitting `/signup`, meaning traffic from the GKE private subnet (`10.0.2.0/24`) is hitting a routing or firewall block before reaching the public subnet VM (`10.0.1.11`).
