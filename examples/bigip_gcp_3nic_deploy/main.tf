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
resource "google_compute_network" "mgmtvpc" {
  name                    = format("%s-mgmtvpc-%s", var.prefix, random_id.id.hex)
  auto_create_subnetworks = false
}
resource "google_compute_network" "extvpc" {
  name                    = format("%s-extvpc-%s", var.prefix, random_id.id.hex)
  auto_create_subnetworks = false
}
resource "google_compute_network" "intvpc" {
  name                    = format("%s-intvpc-%s", var.prefix, random_id.id.hex)
  auto_create_subnetworks = false
}
resource "google_compute_subnetwork" "mgmt_subnetwork" {
  name          = format("%s-mgmt-%s", var.prefix, random_id.id.hex)
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.mgmtvpc.id
}
resource "google_compute_subnetwork" "external_subnetwork" {
  name          = format("%s-ext-%s", var.prefix, random_id.id.hex)
  ip_cidr_range = "10.0.2.0/24"
  region        = var.region
  network       = google_compute_network.extvpc.id
}

resource "google_compute_subnetwork" "internal_subnetwork" {
  name          = format("%s-int-%s", var.prefix, random_id.id.hex)
  ip_cidr_range = "10.0.3.0/24"
  region        = var.region
  network       = google_compute_network.intvpc.id
}

resource "google_compute_firewall" "mgmt_firewall" {
  name    = format("%s-mgmt-firewall-%s", var.prefix, random_id.id.hex)
  network = google_compute_network.mgmtvpc.id
  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "8443"]
  }
  allow {
    protocol = "icmp"
  }
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "ext_firewall" {
  name    = format("%s-ext-firewall-%s", var.prefix, random_id.id.hex)
  network = google_compute_network.extvpc.id
  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "8443"]
  }
  allow {
    protocol = "icmp"
  }
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "int_firewall" {
  name    = format("%s-intvpc-firewall-%s", var.prefix, random_id.id.hex)
  network = google_compute_network.intvpc.id
  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "8443"]
  }
  allow {
    protocol = "icmp"
  }
  source_ranges = ["0.0.0.0/0"]
}

# module "bigip" {
#   count               = var.instance_count
#   source              = "../.."
#   prefix              = format("%s-3nic", var.prefix)
#   project_id          = var.project_id
#   zone                = var.zone
#   image               = var.image
#   service_account     = var.service_account
#   mgmt_subnet_ids     = [{ "subnet_id" = google_compute_subnetwork.mgmt_subnetwork.id, "public_ip" = true, "private_ip_primary" = "" }]
#   external_subnet_ids = [{ "subnet_id" = google_compute_subnetwork.external_subnetwork.id, "public_ip" = false, "private_ip_primary" = "", "private_ip_secondary" = "" }]
#   internal_subnet_ids = [{ "subnet_id" = google_compute_subnetwork.internal_subnetwork.id, "public_ip" = false, "private_ip_primary" = "", "private_ip_secondary" = "" }]
# }


# Create VM
resource "google_compute_instance" "vm_instance_public" {
  name         = format("%s-ubuntuvm01-%s", var.prefix, random_id.id.hex)
  machine_type = "n2-standard-2"
  zone         = var.zone
  hostname     = format("%s-ubuntuvm01-%s.com", var.prefix, random_id.id.hex)
  tags         = ["ssh", "http"]
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
    }
  }
  metadata_startup_script = templatefile("ubunturun.sh", {})
  network_interface {
    subnetwork = google_compute_subnetwork.mgmt_subnetwork.id
    access_config {}
  }
  network_interface {
    subnetwork = google_compute_subnetwork.internal_subnetwork.id

    # access_config { }
  }
  metadata = merge(var.metadata, coalesce(var.f5_ssh_publickey, "unspecified") != "unspecified" ? {
    sshKeys = file(var.f5_ssh_publickey)
    } : {}
  )
}
