output "bigip_password" {
  value = module.bigip.*.bigip_password
}
output "mgmtPublicIP" {
  value = module.bigip.*.mgmtPublicIP
}
output "bigip_username" {
  value = module.bigip.*.f5_username
}
output "mgmtPort" {
  value = module.bigip.*.mgmtPort
}
output "public_addresses" {
  value = module.bigip.*.public_addresses
}
output "private_addresses" {
  value = module.bigip.*.private_addresses
}
output "service_account" {
  value = module.bigip.*.service_account
}
