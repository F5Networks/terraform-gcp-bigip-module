variable "project_id" {
  description = "Google Cloud Platform (GCP) Project ID."
  type        = string
}

variable "region" {
  description = "GCP region name."
  type        = string
}

variable "prefix" {
  description = "Prefix for resources created by this module"
  type        = string
  default     = "tf-gcp-bigip"
}

variable "zone" {
  type        = string
  default     = "us-central1-a"
  description = "The compute zones which will host the BIG-IP VMs"
}

variable "name" {
  description = "Web server name."
  type        = string
  default     = "my-nginx-webserver"
}

variable "machine_type" {
  description = "GCP VM instance machine type."
  type        = string
  default     = "f1-micro"
}

variable "labels" {
  description = "List of labels to attach to the VM instance."
  type        = map(any)
}
