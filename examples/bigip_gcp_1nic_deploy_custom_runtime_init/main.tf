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

data "template_file" "user_data_vm0" {
  template = file("custom_onboard_big.tmpl")
  vars = {
    onboard_log                       = var.onboard_log
    libs_dir                          = var.libs_dir
    bigip_username                    = var.f5_username
    gcp_secret_manager_authentication = var.gcp_secret_manager_authentication
    bigip_password                    = (var.f5_password == "") ? (var.gcp_secret_manager_authentication ? var.gcp_secret_name : random_string.password.result) : var.f5_password
    ssh_keypair                       = file(var.f5_ssh_publickey)
    INIT_URL                          = var.INIT_URL,
    DO_URL                            = var.DO_URL,
    DO_VER                            = split("/", var.DO_URL)[7]
    AS3_URL                           = var.AS3_URL,
    AS3_VER                           = split("/", var.AS3_URL)[7]
    TS_VER                            = split("/", var.TS_URL)[7]
    TS_URL                            = var.TS_URL,
    CFE_VER                           = split("/", var.CFE_URL)[7]
    CFE_URL                           = var.CFE_URL,
    FAST_URL                          = var.FAST_URL
    FAST_VER                          = split("/", var.FAST_URL)[7]
    NIC_COUNT                         = false
  }
}

module "bigip" {
  count            = var.instance_count
  source           = "../.."
  prefix           = format("%s-1nic", var.prefix)
  project_id       = var.project_id
  zone             = var.zone
  image            = var.image
  service_account  = var.service_account
  mgmt_subnet_ids  = [{ "subnet_id" = google_compute_subnetwork.mgmt_subnetwork.id, "public_ip" = true, "private_ip_primary" = "" }]
  custom_user_data = data.template_file.user_data_vm0.rendered
}

