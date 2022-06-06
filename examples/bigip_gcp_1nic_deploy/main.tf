terraform {
  required_version = ">= 0.13"
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Create a random id
#
resource "random_id" "id" {
  byte_length = 2
}

# Create random password for BIG-IP
#
resource "random_string" "password" {
  length      = 16
  min_upper   = 1
  min_lower   = 1
  min_numeric = 1
  special     = false
}

resource "google_compute_network" "vpc" {
  name                    = format("%s-vpc-%s", var.prefix, random_id.id.hex)
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "mgmt_subnetwork" {
  name          = format("%s-mgmt-%s", var.prefix, random_id.id.hex)
  ip_cidr_range = "10.0.0.0/16"
  region        = var.region
  network       = google_compute_network.vpc.id
}

resource "google_compute_firewall" "mgmt_firewall" {
  name    = format("%s-mgmt-firewall-%s", var.prefix, random_id.id.hex)
  network = google_compute_network.vpc.id
  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "8443"]
  }
  allow {
    protocol = "icmp"
  }
  source_ranges = ["0.0.0.0/0"]
}

resource "google_service_account" "f5_bigip_user" {
  account_id  = "f5-bigip-user"
  description = "User for F5 BIGIP"
}

module "bigip" {
  count           = var.instance_count
  source          = "../.."
  prefix          = format("%s-1nic", var.prefix)
  project_id      = var.project_id
  zone            = var.zone
  image           = var.image
  service_account = google_service_account.f5_bigip_user.email
  mgmt_subnet_ids = [{ "subnet_id" = google_compute_subnetwork.mgmt_subnetwork.id, "public_ip" = true, "private_ip_primary" = "" }]
}

