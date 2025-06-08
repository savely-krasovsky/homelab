variable "bws_access_token" {
  description = "Bitwarden Secrets CLI access token"
  type = string
  sensitive = true
}

variable "proxmox_config" {
  description = "Proxmox credentials"
  type = object({
    host = string
    password_secret_id = string
  })
}

variable "containers_config" {
  description = "Shared configuration"
  type = object({
    email = string
    base_domain = string
    ews_domain = string
  })
}

variable "containers_secret_config" {
  description = "Quadlet Ssecret"
  type = map(string)
  default = {
    traefik_cf_dns_api_token                  = "e9e0f0f0-abc8-4bde-b05f-b292018179bb"
    vmauth_traefik_bearer_token               = "fba802cf-948f-4ff7-8965-b29f00e2da48"
    vmauth_proxmox_bearer_token               = "bb281df0-e5e8-4348-a92e-b2a300a30117"
    oauth2_proxy_cookie_secret                = "289c0832-27c2-463b-97b7-b29200a8cebd"
    oauth2_proxy_client_secret                = "afdb8ef2-a3d4-4a17-b839-b29200ab6f87"
    pocket_id_maxmind_license_key             = "08c549a4-bf48-4998-8cb0-b29200ac845d"
    actual_budget_openid_client_secret        = "5754702b-d9d5-4127-b5ab-b29200abdd6a"
    open_webui_oauth_client_secret            = "b595040b-a23a-44af-8bff-b29200ad6258"
    open_webui_google_drive_api_key           = "d24bf77b-622d-4ef0-88ae-b2b200d67ee1"
    open_webui_anthropic_api_key              = "104a349b-a4be-4d3a-9c0b-b2c700e64c9a"
    open_webui_google_api_key                 = "3016f3ef-c14c-4f4c-8439-b2c700e62f21"
    open_webui_openai_api_key                 = "24fd45e2-0fd3-42cd-8fd5-b2c700e66731"
    karakeep_oauth_client_secret              = "784d379b-bcaf-424f-bc77-b29500ff1be6"
    karakeep_openai_api_key                   = "98f5ccdf-d4b1-4883-b4e3-b295010ba589"
    meili_master_key                          = "a67874c5-95c2-4f7a-b335-b295010010e0"
    nextauth_secret                           = "94b4b746-f005-46e0-b60a-b29501010c06"
    immich_postgres_password                  = "386f1adc-878f-4755-a06b-b29700b15cd0"
    immich_map_key                            = "b5735614-bc05-441d-a2e2-b29800d3b25c"
    miniflux_postgres_password                = "1c6a587e-9dda-47de-953a-b29a01697231"
    miniflux_database_url                     = "456f8488-cdeb-4246-959d-b29a016be9ac"
    miniflux_oauth2_client_secret             = "3bb3cedd-1ee4-4624-b865-b29a016c2318"
    pds_jwt_secret                            = "b9dfaefd-3083-4e2f-a23f-b29a017db774"
    pds_admin_password                        = "00e810b5-6d8b-4342-8189-b29a017dca5e"
    pds_plc_rotation_key_k256_private_key_hex = "e0825e62-8d49-4b4a-99cd-b29a017def90"
    pds_email_smtp_url                        = "5a940d99-28cb-4792-9825-b29a017e11ad"
    outline_secret_key                        = "501e040c-5574-4058-a0c0-b29d01010c09"
    outline_utils_secret                      = "b032948f-bce3-46bb-bd26-b29d01012dde"
    outline_database_url                      = "5887f243-6332-4041-8457-b29d0104be2e"
    outline_postgres_password                 = "4212e3a7-acd3-4804-ac0e-b29d01015850"
    outline_oidc_client_secret                = "9c8cae9a-db6d-45d0-8cc0-b29d0101844c"
    outline_smtp_password                     = "5fdbfb32-257e-4cc3-8b07-b29d01063ba6"
    grafana_oauth2_client_secret              = "697cf367-a80c-41f6-b975-b2a200a986d8"
    glance_github_token                       = "de3353d8-09d9-4063-b513-b2a3008cc2c9"
    tangled_knot_server_secret                = "a58caac0-1c07-4152-89e6-b2a900c8fe8f"
    forward_info_bot_telegram_token           = "f8eda775-f945-4eb8-b48a-b2b80092cf54"
    restic_aws_access_key_id                  = "2743cf63-05ae-45b4-997f-b2c700dfabef"
    restic_aws_secret_access_key              = "134279a9-b3ee-4309-ae9e-b2c700dfe86c"
    restic_b2_account_id                      = "3e058bd3-e13d-4b6a-9d48-b2c700e00d62"
    restic_b2_account_key                     = "ddc2f07b-47ca-49b2-ae41-b2c700e02f01"
    restic_password                           = "52ce5eb2-98ae-4243-ba08-b2c700e04b7e"
    opencloud_collabora_password              = "bced1168-9741-4b8e-abf4-b2d4000e2c9e"
    opencloud_smtp_password                   = "5e0889ac-3b11-4fc4-81ca-b2d400170e85"
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
