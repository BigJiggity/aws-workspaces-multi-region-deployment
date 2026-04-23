# Common configuration shared across WorkSpaces units in this account/region.

locals {
  account_scope = "account-111122223333"
  region        = "us-east-1"

  directory_id      = "d-0000000000"
  directory_name    = "example.local"
  pool_directory_id = "wsd-00000000"

  workspaces_subnets = {
    "10.164.98.128/25" = { az = "us-east-1b", az_id = "use1-az2" }
    "10.164.99.0/25" = { az = "us-east-1c", az_id = "use1-az4" }
  }

  workspaces_running_mode      = "AUTO_STOP"
  workspaces_auto_stop_timeout = 60
  workspaces_create_timeout    = "120m"

  default_bundles = {
    standard = "wsb-00000000"
    soc      = "wsb-00000001"
    dev      = "wsb-00000002"
  }

  trusted_cidrs = [
    {
      source      = "10.164.0.0/16"
      description = "Trusted CIDR"
    },  ]

  backend = {
    bucket         = "example-workspaces-terraform-state"
    dynamodb_table = "example-workspaces-platform-dev-terraform-locks"
    region         = "us-east-1"
    kms_key_id     = "alias/example-workspaces-platform-dev-terraform-state-01"
  }
}
