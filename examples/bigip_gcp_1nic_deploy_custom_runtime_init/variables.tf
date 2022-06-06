variable "instance_count" {
  description = "Number of Bigip instances to create( From terraform 0.13, module supports count feature to spin mutliple instances )"
  type        = number
  default     = 1
}
variable "prefix" {
  description = "Prefix for resources created by this module"
  type        = string
  default     = "tf-gcp-bigip"
}
variable "project_id" {
  type        = string
  description = "The GCP project identifier where the cluster will be created."
}
variable "region" {
  type        = string
  description = "The compute region which will host the BIG-IP VMs"
}
variable "zone" {
  type        = string
  default     = "us-central1-a"
  description = "The compute zones which will host the BIG-IP VMs"
}
variable "image" {
  type        = string
  default     = "projects/f5-7626-networks-public/global/images/f5-bigip-16-1-2-2-0-0-28-payg-best-plus-25mbps-220505080809"
  description = "The self-link URI for a BIG-IP image to use as a base for the VM cluster. This can be an official F5 image from GCP Marketplace, or a customised image."
}

variable "service_account" {
  description = "service account email to use with BIG-IP vms"
  type        = string
}

variable "f5_username" {
  description = "The admin username of the F5 Bigip that will be deployed"
  default     = "bigipuser"
}

variable "f5_password" {
  description = "The admin password of the F5 Bigip that will be deployed"
  default     = ""
}

variable "onboard_log" {
  description = "Directory on the BIG-IP to store the cloud-init logs"
  default     = "/var/log/startup-script.log"
  type        = string
}

variable "libs_dir" {
  description = "Directory on the BIG-IP to download the A&O Toolchain into"
  default     = "/config/cloud/gcp/node_modules"
  type        = string
}

variable "gcp_secret_manager_authentication" {
  description = "Whether to use secret manager to pass authentication"
  type        = bool
  default     = false
}

variable "gcp_secret_name" {
  description = "The secret to get the secret version for"
  type        = string
  default     = ""
}

variable "gcp_secret_version" {
  description = "(Optional)The version of the secret to get. If it is not provided, the latest version is retrieved."
  type        = string
  default     = "latest"
}

## Please check and update the latest DO URL from https://github.com/F5Networks/f5-declarative-onboarding/releases
# always point to a specific version in order to avoid inadvertent configuration inconsistency
variable "DO_URL" {
  description = "URL to download the BIG-IP Declarative Onboarding module"
  type        = string
  default     = "https://github.com/F5Networks/f5-declarative-onboarding/releases/download/v1.21.0/f5-declarative-onboarding-1.21.0-3.noarch.rpm"
}
## Please check and update the latest AS3 URL from https://github.com/F5Networks/f5-appsvcs-extension/releases/latest 
# always point to a specific version in order to avoid inadvertent configuration inconsistency
variable "AS3_URL" {
  description = "URL to download the BIG-IP Application Service Extension 3 (AS3) module"
  type        = string
  default     = "https://github.com/F5Networks/f5-appsvcs-extension/releases/download/v3.28.0/f5-appsvcs-3.28.0-3.noarch.rpm"
}

## Please check and update the latest TS URL from https://github.com/F5Networks/f5-telemetry-streaming/releases/latest 
# always point to a specific version in order to avoid inadvertent configuration inconsistency
variable "TS_URL" {
  description = "URL to download the BIG-IP Telemetry Streaming module"
  type        = string
  default     = "https://github.com/F5Networks/f5-telemetry-streaming/releases/download/v1.20.0/f5-telemetry-1.20.0-3.noarch.rpm"
}

## Please check and update the latest Failover Extension URL from https://github.com/f5devcentral/f5-cloud-failover-extension/releases/latest 
# always point to a specific version in order to avoid inadvertent configuration inconsistency
variable "CFE_URL" {
  description = "URL to download the BIG-IP Cloud Failover Extension module"
  type        = string
  default     = "https://github.com/F5Networks/f5-cloud-failover-extension/releases/download/v1.8.0/f5-cloud-failover-1.8.0-0.noarch.rpm"
}

## Please check and update the latest FAST URL from https://github.com/F5Networks/f5-appsvcs-templates/releases/latest 
# always point to a specific version in order to avoid inadvertent configuration inconsistency
variable "FAST_URL" {
  description = "URL to download the BIG-IP FAST module"
  type        = string
  default     = "https://github.com/F5Networks/f5-appsvcs-templates/releases/download/v1.9.0/f5-appsvcs-templates-1.9.0-1.noarch.rpm"
}
## Please check and update the latest runtime init URL from https://github.com/F5Networks/f5-bigip-runtime-init/releases/latest
# always point to a specific version in order to avoid inadvertent configuration inconsistency
variable "INIT_URL" {
  description = "URL to download the BIG-IP runtime init"
  type        = string
  default     = "https://cdn.f5.com/product/cloudsolutions/f5-bigip-runtime-init/v1.2.1/dist/f5-bigip-runtime-init-1.2.1-1.gz.run"
}

variable "labels" {
  description = "An optional map of key:value labels to add to the instance"
  type        = map(string)
  default     = {}
}

variable "f5_ssh_publickey" {
  description = "Path to the public key to be used for ssh access to the VM.  Only used with non-Windows vms and can be left as-is even if using Windows vms. If specifying a path to a certification on a Windows machine to provision a linux vm use the / in the path versus backslash. e.g. c:/home/id_rsa.pub"
  default     = "~/.ssh/id_rsa.pub"
}