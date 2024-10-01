
terraform {
  required_version = ">= 0.13"
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

# resource "google_compute_network" "intvpc" {
#   name                    = format("%s-intvpc-%s", var.prefix, random_id.id.hex)
#   auto_create_subnetworks = false
# }

resource "google_compute_subnetwork" "mgmt_subnetwork" {
  name          = format("%s-mgmt-%s", var.prefix, random_id.id.hex)
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.mgmtvpc.id
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

resource "google_compute_subnetwork" "external_subnetwork" {
  name          = format("%s-ext-%s", var.prefix, random_id.id.hex)
  ip_cidr_range = "10.0.2.0/24"
  region        = var.region
  network       = google_compute_network.extvpc.id
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

# resource "google_compute_subnetwork" "internal_subnetwork" {
#   name          = format("%s-int-%s", var.prefix, random_id.id.hex)
#   ip_cidr_range = "10.0.3.0/24"
#   region        = var.region
#   network       = google_compute_network.intvpc.id
# }

data "google_compute_image" "ubuntu" {
  family  = "ubuntu-2204-lts"
  project = "ubuntu-os-cloud"
}


# Creates a GCP VM Instance.  Metadata Startup script install the Nginx webserver.
resource "google_compute_instance" "vm" {
  name         = var.name
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["http-server"]
  labels       = var.labels

  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu.self_link
    }
  }
  network_interface {
    subnetwork = google_compute_subnetwork.mgmt_subnetwork.id
    access_config {
      // Ephemeral IP
    }
  }
  network_interface {
    subnetwork = google_compute_subnetwork.external_subnetwork.id
  }
  metadata = {
    sshKeys        = file(var.vm_ssh_publickey)
    enable-oslogin = "TRUE"
  }
  metadata_startup_script = templatefile("template/install_nginx.tpl", { ufw_allow_nginx = "Nginx HTTP" })
}

# Creates a GCP VM Instance.  Metadata Startup script install the Nginx webserver.
resource "google_compute_instance" "vm02" {
  name         = format("%s-vm02", var.name)
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["http-server"]
  labels       = var.labels

  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu.self_link
    }
  }
  network_interface {
    subnetwork = google_compute_subnetwork.external_subnetwork.id
  }
  metadata_startup_script = templatefile("template/install_nginx.tpl", { ufw_allow_nginx = "Nginx HTTP" })
}

variable "vm_ssh_publickey" {
  description = "Path to the public key to be used for ssh access to the VM.  Only used with non-Windows vms and can be left as-is even if using Windows vms. If specifying a path to a certification on a Windows machine to provision a linux vm use the / in the path versus backslash. e.g. c:/home/id_rsa.pub"
  default     = "~/.ssh/id_rsa.pub"
}