# Specify the GCP Provider
provider "google" {
  project = var.project_id
  region  = var.region
}


https://artifactory.f5net.com/artifactory/f5-bigiq-mgmt-generic/images/releases/20.2.0/0.2.11/upgrade-bundle/BIG-IP-Next-CentralManager-20.2.0-0.2.11-Update.tgz

# [START storage_flask_google_cloud_quickstart_parent_tag]
# [START compute_flask_quickstart_vpc]
resource "google_compute_network" "vpc_network" {
  name                    = "my-custom-mode-network"
  auto_create_subnetworks = false
  mtu                     = 1460
}

resource "google_compute_subnetwork" "default" {
  name          = "my-custom-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.vpc_network.id
}

resource "google_compute_instance" "default" {
  name         = "ravi-flask-vm"
  machine_type = "f1-micro"
  zone         = var.zone
  tags         = ["ssh"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  # Install Flask
  metadata_startup_script = "sudo apt-get update; sudo apt-get install -yq build-essential python3-pip rsync; pip install flask"

  network_interface {
    subnetwork = google_compute_subnetwork.default.id

    access_config {
      # Include this section to give the VM an external IP address
    }
  }
}
# [END compute_flask_quickstart_vm]

# [START vpc_flask_quickstart_ssh_fw]
resource "google_compute_firewall" "ssh" {
  name = "allow-ssh"
  allow {
    ports    = ["22"]
    protocol = "tcp"
  }
  direction     = "INGRESS"
  network       = google_compute_network.vpc_network.id
  priority      = 1000
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ssh"]
}
# [END vpc_flask_quickstart_ssh_fw]


# [START vpc_flask_quickstart_5000_fw]
resource "google_compute_firewall" "flask" {
  name    = "flask-app-firewall"
  network = google_compute_network.vpc_network.id

  allow {
    protocol = "tcp"
    ports    = ["5000"]
  }
  source_ranges = ["0.0.0.0/0"]
}

# # [END vpc_flask_quickstart_5000_fw]

# # Create new multi-region storage bucket in the US
# # with versioning enabled

# # [START storage_kms_encryption_tfstate]
# resource "google_kms_key_ring" "terraform_state" {
#   name     = "${random_id.bucket_prefix.hex}-bucket-tfstate"
#   location = "us"
# }

# resource "google_kms_crypto_key" "terraform_state_bucket" {
#   name            = "test-terraform-state-bucket"
#   key_ring        = google_kms_key_ring.terraform_state.id
#   rotation_period = "86400s"

#   lifecycle {
#     prevent_destroy = false
#   }
# }

# # Enable the Cloud Storage service account to encrypt/decrypt Cloud KMS keys
# data "google_project" "project" {
# }

# resource "google_project_iam_member" "default" {
#   project = data.google_project.project.project_id
#   role    = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
#   member  = "serviceAccount:service-${data.google_project.project.number}@gs-project-accounts.iam.gserviceaccount.com"
# }
# # [END storage_kms_encryption_tfstate]

# # [START storage_bucket_tf_with_versioning]
# resource "random_id" "bucket_prefix" {
#   byte_length = 8
# }

# resource "google_storage_bucket" "default" {
#   name          = "${random_id.bucket_prefix.hex}-bucket-tfstate"
#   force_destroy = false
#   location      = "US"
#   storage_class = "STANDARD"
#   versioning {
#     enabled = true
#   }
#   encryption {
#     default_kms_key_name = google_kms_crypto_key.terraform_state_bucket.id
#   }
#   depends_on = [
#     google_project_iam_member.default
#   ]
# }
# # [END storage_bucket_tf_with_versioning]
# # [END storage_flask_google_cloud_quickstart_parent_tag]