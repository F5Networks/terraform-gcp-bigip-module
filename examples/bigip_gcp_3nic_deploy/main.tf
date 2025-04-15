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

resource "google_compute_firewall" "int_firewall_egress" {
  name    = format("%s-intvpc-firewall-egress-%s", var.prefix, random_id.id.hex)
  network = google_compute_network.intvpc.id
  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "8443"]
  }
  direction = "EGRESS"
  allow {
    protocol = "icmp"
  }
  source_ranges = ["0.0.0.0/0"]
}

# metadata_startup_script = replace(coalesce(var.custom_user_data, templatefile("${path.module}/startup-script.tpl",
#   {
#     onboard_log                       = var.onboard_log
#     libs_dir                          = var.libs_dir
#     bigip_username                    = var.f5_username
#     gcp_secret_manager_authentication = var.gcp_secret_manager_authentication
#     bigip_password                    = (var.f5_password == "") ? (var.gcp_secret_manager_authentication ? var.gcp_secret_name : random_string.password.result) : var.f5_password
#     ssh_keypair                       = file(var.f5_ssh_publickey)
#     INIT_URL                          = var.INIT_URL,
#     DO_URL                            = var.DO_URL,
#     DO_VER                            = format("v%s", split("-", split("/", var.DO_URL)[length(split("/", var.DO_URL)) - 1])[3])
#     AS3_URL                           = var.AS3_URL,
#     AS3_VER                           = format("v%s", split("-", split("/", var.AS3_URL)[length(split("/", var.AS3_URL)) - 1])[2])
#     TS_VER                            = format("v%s", split("-", split("/", var.TS_URL)[length(split("/", var.TS_URL)) - 1])[2])
#     TS_URL                            = var.TS_URL,
#     CFE_VER                           = format("v%s", split("-", split("/", var.CFE_URL)[length(split("/", var.CFE_URL)) - 1])[3])
#     CFE_URL                           = var.CFE_URL,
#     FAST_URL                          = var.FAST_URL
#     FAST_VER                          = format("v%s", split("-", split("/", var.FAST_URL)[length(split("/", var.FAST_URL)) - 1])[3])
#     NIC_COUNT                         = local.multiple_nic_count > 0 ? true : false
# })), "/\r/", "")

# # Setup Onboarding scripts
# locals {
#   f5_onboard1 = templatefile("${path.module}/f5_onboard.tmpl", {
#     f5_username                       = var.f5_username
#     f5_password                       = var.gcp_secret_manager_authentication ? "" : var.f5_password
#     gcp_secret_manager_authentication = var.gcp_secret_manager_authentication
#     gcp_secret_name                   = var.gcp_secret_manager_authentication ? var.gcp_secret_name : ""
#     gcp_secret_version                = var.gcp_secret_manager_authentication ? var.gcp_secret_version : ""
#     ssh_keypair                       = file(var.ssh_key)
#     gcp_project_id                    = var.gcp_project_id
#     INIT_URL                          = var.INIT_URL
#     DO_URL                            = var.DO_URL
#     AS3_URL                           = var.AS3_URL
#     TS_URL                            = var.TS_URL
#     FAST_URL                          = var.FAST_URL
#     DO_VER                            = split("/", var.DO_URL)[7]
#     AS3_VER                           = split("/", var.AS3_URL)[7]
#     TS_VER                            = split("/", var.TS_URL)[7]
#     FAST_VER                          = split("/", var.FAST_URL)[7]
#     dns_server                        = var.dns_server
#     dns_suffix                        = var.dns_suffix
#     ntp_server                        = var.ntp_server
#     timezone                          = var.timezone
#     bigIqLicenseType                  = var.bigIqLicenseType
#     bigIqHost                         = var.bigIqHost
#     bigIqPassword                     = var.bigIqPassword
#     bigIqUsername                     = var.bigIqUsername
#     bigIqLicensePool                  = var.bigIqLicensePool
#     bigIqSkuKeyword1                  = var.bigIqSkuKeyword1
#     bigIqSkuKeyword2                  = var.bigIqSkuKeyword2
#     bigIqUnitOfMeasure                = var.bigIqUnitOfMeasure
#     bigIqHypervisor                   = var.bigIqHypervisor
#     NIC_COUNT                         = true
#     # public_vip                        = google_compute_address.vip1.address
#   })
# }

module "bigip" {
  count            = var.instance_count
  source           = "../.."
  prefix           = format("%s-3nic", var.prefix)
  project_id       = var.project_id
  zone             = var.zone
  image            = var.image
  service_account  = var.service_account
  sleep_time       = "300s"
  machine_type     = "n2-highmem-4"
  min_cpu_platform = "Intel Cascade Lake" # Add this line
  disk_type        = "pd-ssd"
  # custom_user_data    = local.f5_onboard1
  disk_size_gb        = 120 # Minimum for multi-module provisioning
  mgmt_subnet_ids     = [{ "subnet_id" = google_compute_subnetwork.mgmt_subnetwork.id, "public_ip" = true, "private_ip_primary" = "" }]
  external_subnet_ids = [{ "subnet_id" = google_compute_subnetwork.external_subnetwork.id, "public_ip" = false, "private_ip_primary" = "", "private_ip_secondary" = "" }]
  internal_subnet_ids = [{ "subnet_id" = google_compute_subnetwork.internal_subnetwork.id, "public_ip" = false, "private_ip_primary" = "", "private_ip_secondary" = "" }]
}

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
