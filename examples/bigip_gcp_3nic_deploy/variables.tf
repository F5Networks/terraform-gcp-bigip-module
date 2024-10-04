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
  default     = "projects/f5-7626-networks-public/global/images/f5-bigip-16-1-4-1-0-53-5-payg-best-plus-25mbps-231026120516"
  description = "The self-link URI for a BIG-IP image to use as a base for the VM cluster.This can be an official F5 image from GCP Marketplace, or a customised image."
}

variable "service_account" {
  description = "service account email to use with BIG-IP vms"
  type        = string
}

variable "metadata" {
  description = "Provide custom metadata values for BIG-IP instance"
  type        = map(string)
  default     = {}
}


variable "f5_ssh_publickey" {
  description = "Path to the public key to be used for ssh access to the VM.  Only used with non-Windows vms and can be left as-is even if using Windows vms. If specifying a path to a certification on a Windows machine to provision a linux vm use the / in the path versus backslash. e.g. c:/home/id_rsa.pub"
  default     = "~/.ssh/id_rsa.pub"
}