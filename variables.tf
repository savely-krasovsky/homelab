variable "bws_access_token" {
  description = "Bitwarden Secrets CLI access token"
  type = string
  sensitive = true
}

variable "proxmox_config" {
  description = "Proxmox credentials"
  type = object({
    endpoint = string
    password_secret_id = string
  })
}

# Just base domain for now
variable "quadlets_config" {
  description = "Shared Quadlets configuration"
  type = object({
    base_domain = string
  })
}

variable "quadlets_secret_config" {
  description = "Quadlet Ssecret"
  type = map(string)
  default = {
    traefik_cf_dns_api_token           = "e9e0f0f0-abc8-4bde-b05f-b292018179bb"
    oauth2_proxy_cookie_secret         = "289c0832-27c2-463b-97b7-b29200a8cebd"
    oauth2_proxy_client_secret         = "afdb8ef2-a3d4-4a17-b839-b29200ab6f87"
    pocket_id_maxmind_license_key      = "08c549a4-bf48-4998-8cb0-b29200ac845d"
    actual_budget_openid_client_secret = "5754702b-d9d5-4127-b5ab-b29200abdd6a"
    open_webui_oauth_client_secret     = "b595040b-a23a-44af-8bff-b29200ad6258"
    hoarder_oauth_client_secret        = "784d379b-bcaf-424f-bc77-b29500ff1be6"
    hoarder_openai_api_key             = "98f5ccdf-d4b1-4883-b4e3-b295010ba589"
    meili_master_key                   = "a67874c5-95c2-4f7a-b335-b295010010e0"
    nextauth_secret                    = "94b4b746-f005-46e0-b60a-b29501010c06"
    immich_postgres_password           = "386f1adc-878f-4755-a06b-b29700b15cd0"
    immich_map_key                     = "b5735614-bc05-441d-a2e2-b29800d3b25c"
    miniflux_postgres_password         = "1c6a587e-9dda-47de-953a-b29a01697231"
    miniflux_database_url              = "456f8488-cdeb-4246-959d-b29a016be9ac"
    miniflux_oauth2_client_secret      = "3bb3cedd-1ee4-4624-b865-b29a016c2318"
  }
}

variable "fcos_config" {
  description = "Fedora CoreOS Configuration"
  type = object({
    hostname = string
    ssh_key = string
    root_ca = string

    mac_address = string
    ip = string
    gateway = string
    mask = string
    nameserver = string

    truenas_ip = string
    truenas_iqn = string
  })
}
