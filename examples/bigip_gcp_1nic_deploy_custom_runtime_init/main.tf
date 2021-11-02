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
    bigip_username         = "bigipuser"
    ssh_keypair            = fileexists("~/.ssh/id_rsa.pub") ? file("~/.ssh/id_rsa.pub") : ""
    aws_secretmanager_auth = false
    bigip_password         = "xxxx"
    INIT_URL               = "https://cdn.f5.com/product/cloudsolutions/f5-bigip-runtime-init/v1.2.1/dist/f5-bigip-runtime-init-1.2.1-1.gz.run",
    DO_URL                 = "https://github.com/F5Networks/f5-declarative-onboarding/releases/download/v1.21.0/f5-declarative-onboarding-1.21.0-3.noarch.rpm",
    DO_VER                 = "v1.21.0"
    AS3_URL                = "https://github.com/F5Networks/f5-appsvcs-extension/releases/download/v3.28.0/f5-appsvcs-3.28.0-3.noarch.rpm",
    AS3_VER                = "v3.28.0"
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
  custom_user_data = var.custom_user_data
}

