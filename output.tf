output "mgmtPublicIP" {
  value = join("", [for ac in google_compute_instance.f5vm01.network_interface[local.multiple_nic_count > 0 ? 1 : 0].access_config : ac.nat_ip if ac != null])
}
output "mgmtPort" {
  description = "Mgmt Port"
  value       = length(google_compute_instance.f5vm01.network_interface) > 1 ? "443" : "8443"
}
output "f5_username" {
  value = (var.custom_user_data == null) ? var.f5_username : "Username as provided in custom runtime-init"
}
output "bigip_password" {
  value = (var.custom_user_data == null) ? ((var.f5_password == "") ? (var.gcp_secret_manager_authentication ? data.google_secret_manager_secret_version.secret[0].secret_data : random_string.password.result) : var.f5_password) : "Password as provided in custom runtime-init"
}
output "public_addresses" {
  value = google_compute_instance.f5vm01.network_interface[*].access_config[*].nat_ip
}
output "private_addresses" {
  value = google_compute_instance.f5vm01.network_interface[*].network_ip
}

output "service_account" {
  value = var.service_account
}

output "self_link" {
  value       = google_compute_instance.f5vm01.self_link
  description = "Fully-qualifed self-link of the BIG-IP VM."
}

output "name" {
  value       = google_compute_instance.f5vm01.name
  description = "The final instance name for BIG-IP VM."
}

output "zone" {
  value       = google_compute_instance.f5vm01.zone
  description = "The compute zone for the instance."
}

output "bigip_instance_ids" {
  value = concat(google_compute_instance.f5vm01.*.id)[0]
}
