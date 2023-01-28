
terraform {
  required_providers {
    bigip = {
      source  = "F5Networks/bigip"
      version = "1.16.1"
    }
  }
}

provider "bigip" {
  # Configuration options
  address  = format("https://%s:%s", module.bigip.*.mgmtPublicIP[0], module.bigip.*.mgmtPort[0])
  username = module.bigip.*.f5_username[0]
  password = module.bigip.*.bigip_password[0]
}

resource "bigip_ltm_profile_http" "f5vm02-rechunk-http" {
  name              = "/Common/rechunk-http"
  defaults_from     = "/Common/http"
  response_chunking = "rechunk"
}

# A Virtual server with separate client and server profiles
resource "bigip_ltm_virtual_server" "https" {
  name                       = "/Common/vs_github_test_443"
  destination                = "10.255.255.254"
  description                = "VirtualServer-test"
  port                       = 443
  profiles                   = ["/Common/tcp", bigip_ltm_profile_http.f5vm02-rechunk-http.name]
  client_profiles            = ["/Common/clientssl"]
  server_profiles            = ["/Common/serverssl"]
  security_log_profiles      = ["/Common/global-network"]
  source_address_translation = "automap"
}
