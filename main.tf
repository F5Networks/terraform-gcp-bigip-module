terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 3.51"
    }
  }
}
#
# Create a random id
#
resource "random_id" "module_id" {
  byte_length = 2
}

locals {
  # Emes - none of this commented section should be needed
  # bigip_map = {
  #   "mgmt_subnet_ids"     = var.mgmt_subnet_ids
  #   "external_subnet_ids" = var.external_subnet_ids
  #   "internal_subnet_ids" = var.internal_subnet_ids
  # }
  # mgmt_public_subnet_id = [
  #   for subnet in local.bigip_map["mgmt_subnet_ids"] :
  #   subnet["subnet_id"]
  #   if subnet["public_ip"] == true
  # ]
  # mgmt_private_subnet_id = [
  #   for subnet in local.bigip_map["mgmt_subnet_ids"] :
  #   subnet["subnet_id"]
  #   if subnet["public_ip"] == false
  # ]
  # mgmt_public_private_ip_primary = [
  #   for private in local.bigip_map["mgmt_subnet_ids"] :
  #   private["private_ip_primary"]
  #   if private["public_ip"] == true
  # ]
  # mgmt_private_ip_primary = [
  #   for private in local.bigip_map["mgmt_subnet_ids"] :
  #   private["private_ip_primary"]
  #   if private["public_ip"] == false
  # ]
  # external_public_subnet_id = [
  #   for subnet in local.bigip_map["external_subnet_ids"] :
  #   subnet["subnet_id"]
  #   if subnet["public_ip"] == true
  # ]
  # external_private_subnet_id = [
  #   for subnet in local.bigip_map["external_subnet_ids"] :
  #   subnet["subnet_id"]
  #   if subnet["public_ip"] == false
  # ]
  # internal_public_subnet_id = [
  #   for subnet in local.bigip_map["internal_subnet_ids"] :
  #   subnet["subnet_id"]
  #   if subnet["public_ip"] == true
  # ]
  # internal_private_subnet_id = [
  #   for subnet in local.bigip_map["internal_subnet_ids"] :
  #   subnet["subnet_id"]
  #   if subnet["public_ip"] == false
  # ]
  # internal_private_ip_primary = [
  #   for private in local.bigip_map["internal_subnet_ids"] :
  #   private["private_ip_primary"]
  #   if private["public_ip"] == false
  # ]
  # external_private_ip_primary = [
  #   for private in local.bigip_map["external_subnet_ids"] :
  #   private["private_ip_primary"]
  #   if private["public_ip"] == false
  # ]
  # external_private_ip_secondary = [
  #   for private in local.bigip_map["external_subnet_ids"] :
  #   private["private_ip_secondary"]
  #   if private["public_ip"] == false
  # ]
  # external_public_private_ip_primary = [
  #   for private in local.bigip_map["external_subnet_ids"] :
  #   private["private_ip_primary"]
  #   if private["public_ip"] == true
  # ]
  # external_public_private_ip_secondary = [
  #   for private in local.bigip_map["external_subnet_ids"] :
  #   private["private_ip_secondary"]
  #   if private["public_ip"] == true
  # ]
  # total_nics      = length(concat(local.mgmt_public_subnet_id, local.mgmt_private_subnet_id, local.external_public_subnet_id, local.external_private_subnet_id, local.internal_public_subnet_id, local.internal_private_subnet_id))
  external_nic_count = length([for subnet in var.external_subnet_ids : subnet if subnet.subnet_id != null && subnet.subnet_id != ""]) == 0 ? 0 : 1
  internal_nic_count = length([for subnet in var.internal_subnet_ids : subnet if subnet.subnet_id != null && subnet.subnet_id != ""]) == 0 ? 0 : 1
  multiple_nic_count = local.external_nic_count + local.internal_nic_count
  instance_prefix    = format("%s-%s", var.prefix, random_id.module_id.hex)
}

resource "random_string" "password" {
  length      = 16
  min_upper   = 1
  min_lower   = 1
  min_numeric = 1
  special     = false
}

resource "random_string" "sa_role" {
  length    = 16
  min_lower = 1
  number    = false
  upper     = false
  special   = false
}

data "template_file" "startup_script" {
  template = file("${path.module}/startup-script.tpl")
  vars = {
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
    NIC_COUNT                         = local.multiple_nic_count > 0 ? true : false
  }
}

data "google_secret_manager_secret_version" "secret" {
  count   = var.gcp_secret_manager_authentication ? 1 : 0
  secret  = var.gcp_secret_name
  version = var.gcp_secret_version
}

resource "google_project_iam_member" "gcp_role_member_assignment" {
  count   = var.gcp_secret_manager_authentication ? 1 : 0
  project = var.project_id
  role    = format("projects/${var.project_id}/roles/%s", random_string.sa_role.result)
  member  = "serviceAccount:${var.service_account}"
}

resource "google_project_iam_custom_role" "gcp_custom_roles" {
  count       = var.gcp_secret_manager_authentication ? 1 : 0
  role_id     = random_string.sa_role.result
  title       = random_string.sa_role.result
  description = "IAM for authentication"
  permissions = ["secretmanager.versions.access"]
}


resource "google_compute_address" "mgmt_public_ip" {
  count = length([for address in compact([for subnet in var.mgmt_subnet_ids : subnet.public_ip]) : address if address])
  name  = format("%s-mgmt-publicip-%s", var.prefix, random_id.module_id.hex)
}
resource "google_compute_address" "external_public_ip" {
  count = length([for address in compact([for subnet in var.external_subnet_ids : subnet.public_ip]) : address if address])
  name  = format("%s-ext-publicip-%s-%s", var.prefix, count.index, random_id.module_id.hex)
}

resource "google_compute_instance" "f5vm01" {
  name = var.vm_name == "" ? format("%s", local.instance_prefix) : var.vm_name
  zone = var.zone
  # Scheduling options
  min_cpu_platform = var.min_cpu_platform
  machine_type     = var.machine_type
  scheduling {
    automatic_restart = var.automatic_restart
    preemptible       = var.preemptible
  }
  boot_disk {
    auto_delete = true
    initialize_params {
      type  = var.disk_type
      size  = var.disk_size_gb
      image = var.image
    }
  }
  service_account {
    email  = var.service_account
    scopes = ["cloud-platform"]
  }
  can_ip_forward = true

  #Assign external Nic
  dynamic "network_interface" {
    for_each = [for subnet in var.external_subnet_ids : subnet if subnet.subnet_id != null && subnet.subnet_id != ""]
    content {
      subnetwork = network_interface.value.subnet_id
      network_ip = network_interface.value.private_ip_primary
      dynamic "access_config" {
        for_each = element(coalescelist(compact([network_interface.value.public_ip]), [false]), 0) ? [1] : []
        content {
          nat_ip = google_compute_address.external_public_ip[tonumber(network_interface.key)].address
        }
      }
      dynamic "alias_ip_range" {
        for_each = compact([network_interface.value.private_ip_secondary])
        content {
          ip_cidr_range = alias_ip_range.value
        }
      }
    }
  }


  #Assign to Management Nic
  dynamic "network_interface" {
    for_each = [for subnet in var.mgmt_subnet_ids : subnet if subnet.subnet_id != null && subnet.subnet_id != ""]
    content {
      subnetwork = network_interface.value.subnet_id
      network_ip = network_interface.value.private_ip_primary
      dynamic "access_config" {
        for_each = element(coalescelist(compact([network_interface.value.public_ip]), [false]), 0) ? [1] : []
        content {
          nat_ip = google_compute_address.mgmt_public_ip[tonumber(network_interface.key)].address
        }
      }
    }
  }




  # Internal NIC
  dynamic "network_interface" {
    for_each = [for subnet in var.internal_subnet_ids : subnet if subnet.subnet_id != null && subnet.subnet_id != ""]
    content {
      subnetwork = network_interface.value.subnet_id
      network_ip = network_interface.value.private_ip_primary
      dynamic "access_config" {
        for_each = element(coalescelist(compact([network_interface.value.public_ip]), [false]), 0) ? [1] : []
        content {
          nat_ip = google_compute_address.internal_public_ip[tonumber(network_interface.key)].address
        }
      }
    }
  }

  metadata_startup_script = replace(coalesce(var.custom_user_data, data.template_file.startup_script.rendered), "/\r/", "")

  metadata = merge(var.metadata, coalesce(var.f5_ssh_publickey, "unspecified") != "unspecified" ? {
    sshKeys = file(var.f5_ssh_publickey)
    } : {}
  )
  labels = var.labels
}

resource "time_sleep" "wait_for_google_compute_instance_f5vm" {
  depends_on      = [google_compute_instance.f5vm01]
  create_duration = var.sleep_time
}
