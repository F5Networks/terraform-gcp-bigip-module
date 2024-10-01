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


module "bigip" {
  count           = var.instance_count
  source          = "../.."
  prefix          = format("%s-3nic", var.prefix)
  project_id      = var.project_id
  zone            = var.zone
  image           = var.image
  service_account = var.service_account
  mgmt_subnet_ids     = [{ "subnet_id" = google_compute_subnetwork.mgmt_subnetwork.id, "public_ip" = false, "private_ip_primary" = "" }]
  external_subnet_ids = [{ "subnet_id" = google_compute_subnetwork.external_subnetwork.id, "public_ip" = false, "private_ip_primary" = "", "private_ip_secondary" = "" }]
  internal_subnet_ids = [{ "subnet_id" = google_compute_subnetwork.internal_subnetwork.id, "public_ip" = false, "private_ip_primary" = "", "private_ip_secondary" = "" }]
  custom_user_data = templatefile("custom_onboard_big.tpl",
    {
      onboard_log                       = var.onboard_log
      libs_dir                          = var.libs_dir
      bigip_username                    = var.f5_username
      gcp_secret_manager_authentication = var.gcp_secret_manager_authentication
      bigip_password                    = (var.f5_password == "") ? (var.gcp_secret_manager_authentication ? var.gcp_secret_name : random_string.password.result) : var.f5_password
      ssh_keypair                       = file(var.f5_ssh_publickey)
      INIT_URL                          = var.INIT_URL,
      DO_URL                            = var.DO_URL,
      DO_VER                            = format("v%s", split("-", split("/", var.DO_URL)[length(split("/", var.DO_URL)) - 1])[3])
      AS3_URL                           = var.AS3_URL,
      AS3_VER                           = format("v%s", split("-", split("/", var.AS3_URL)[length(split("/", var.AS3_URL)) - 1])[2])
      TS_VER                            = format("v%s", split("-", split("/", var.TS_URL)[length(split("/", var.TS_URL)) - 1])[2])
      TS_URL                            = var.TS_URL,
      CFE_VER                           = format("v%s", split("-", split("/", var.CFE_URL)[length(split("/", var.CFE_URL)) - 1])[3])
      CFE_URL                           = var.CFE_URL,
      FAST_URL                          = var.FAST_URL
      FAST_VER                          = format("v%s", split("-", split("/", var.FAST_URL)[length(split("/", var.FAST_URL)) - 1])[3])
      NIC_COUNT                         = true
  })
}