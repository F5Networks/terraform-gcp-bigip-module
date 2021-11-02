terraform {
  required_version = ">= 0.13"
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

#
# Create a random id
#
resource "random_id" "id" {
  byte_length = 2
}

resource "google_compute_network" "mgmt_network" {
  name                    = format("%s-mgmt-network-%s", var.prefix, random_id.id.hex)
  auto_create_subnetworks = false
}
resource "google_compute_subnetwork" "mgmt_subnetwork" {
  name          = format("%s-mgmt-subnetwork-%s", var.prefix, random_id.id.hex)
  ip_cidr_range = "10.1.0.0/16"
  region        = "us-central1"
  network       = google_compute_network.mgmt_network.id
}

resource "google_compute_firewall" "default" {
  name    = format("%s-mgmt-firewall-%s", var.prefix, random_id.id.hex)
  network = google_compute_network.mgmt_network.id
  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "8443"]
  }
  allow {
    protocol = "icmp"
  }
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_network" "external_network" {
  name                    = format("%s-external-network-%s", var.prefix, random_id.id.hex)
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "external_subnetwork" {
  name          = format("%s-external-subnetwork-%s", var.prefix, random_id.id.hex)
  ip_cidr_range = "10.2.0.0/16"
  region        = "us-central1"
  network       = google_compute_network.external_network.id
}

resource "google_compute_firewall" "external" {
  name    = format("%s-external-firewall-%s", var.prefix, random_id.id.hex)
  network = google_compute_network.external_network.id
  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "8443"]
  }
  allow {
    protocol = "icmp"
  }
  source_ranges = ["0.0.0.0/0"]
}
resource "google_compute_network" "internal_network" {
  name                    = format("%s-internal-network-%s", var.prefix, random_id.id.hex)
  auto_create_subnetworks = false
}
resource "google_compute_subnetwork" "internal_subnetwork" {
  name          = format("%s-internal-subnetwork-%s", var.prefix, random_id.id.hex)
  ip_cidr_range = "10.3.0.0/16"
  region        = "us-central1"
  network       = google_compute_network.internal_network.id
}
resource "google_compute_firewall" "internal" {
  name    = format("%s-internal-firewall-%s", var.prefix, random_id.id.hex)
  network = google_compute_network.internal_network.id
  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "8443"]
  }
  allow {
    protocol = "icmp"
  }
  source_ranges = ["0.0.0.0/0"]
}
resource "google_compute_network" "external_network2" {
  name                    = format("%s-external-network2-%s", var.prefix, random_id.id.hex)
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "external_subnetwork2" {
  name          = format("%s-external-subnetwork2-%s", var.prefix, random_id.id.hex)
  ip_cidr_range = "10.4.0.0/16"
  region        = "us-central1"
  network       = google_compute_network.external_network2.id
}
resource "google_compute_firewall" "external2" {
  name    = format("%s-external2-firewall-%s", var.prefix, random_id.id.hex)
  network = google_compute_network.external_network2.id
  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "8443"]
  }
  allow {
    protocol = "icmp"
  }
  source_ranges = ["0.0.0.0/0"]
}
module "bigip" {
  count               = var.instance_count
  source              = "../.."
  prefix              = format("%s-4nic", var.prefix)
  project_id          = var.project_id
  zone                = var.zone
  image               = var.image
  service_account     = var.service_account
  mgmt_subnet_ids     = [{ "subnet_id" = google_compute_subnetwork.mgmt_subnetwork.id, "public_ip" = true, "private_ip_primary" = "" }]
  external_subnet_ids = ([{ "subnet_id" = google_compute_subnetwork.external_subnetwork.id, "public_ip" = true, "private_ip_primary" = "", "private_ip_secondary" = "" }, { "subnet_id" = google_compute_subnetwork.external_subnetwork2.id, "public_ip" = true, "private_ip_primary" = "", "private_ip_secondary" = "" }])
  internal_subnet_ids = [{ "subnet_id" = google_compute_subnetwork.internal_subnetwork.id, "public_ip" = false, "private_ip_primary" = "" }]
}

