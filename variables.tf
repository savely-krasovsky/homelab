variable "bws_access_token" {
  description = "Bitwarden Secrets CLI access token"
  type        = string
  sensitive   = true
}

variable "proxmox_config" {
  description = "Proxmox credentials"
  type = object({
    host               = string
    password_secret_id = string
  })
}

variable "containers_config" {
  description = "Shared configuration"
  type = object({
    email       = string
    base_domain = string
    ews_domain  = string
    public_ip   = string
  })
}

variable "containers_secret_config" {
  description = "Quadlet Secret"
  type        = map(string)
  default = {
    traefik_cf_dns_api_token                            = "e9e0f0f0-abc8-4bde-b05f-b292018179bb"
    vmauth_traefik_bearer_token                         = "fba802cf-948f-4ff7-8965-b29f00e2da48"
    vmauth_proxmox_bearer_token                         = "bb281df0-e5e8-4348-a92e-b2a300a30117"
    vmauth_fedora_coreos_bearer_token                   = "2558d1e5-9e89-48c6-82e1-b3e300bb400b"
    oauth2_proxy_cookie_secret                          = "289c0832-27c2-463b-97b7-b29200a8cebd"
    oauth2_proxy_client_secret                          = "afdb8ef2-a3d4-4a17-b839-b29200ab6f87"
    pocket_id_encryption_key                            = "60f943d2-0a2a-49da-95f7-b3c60143ecbb"
    pocket_id_maxmind_license_key                       = "08c549a4-bf48-4998-8cb0-b29200ac845d"
    actual_budget_openid_client_secret                  = "5754702b-d9d5-4127-b5ab-b29200abdd6a"
    open_webui_secret_key                               = "aeeb7cdd-d10e-41d4-abb4-b33300dabc1a"
    open_webui_oauth_client_secret                      = "b595040b-a23a-44af-8bff-b29200ad6258"
    open_webui_google_drive_api_key                     = "d24bf77b-622d-4ef0-88ae-b2b200d67ee1"
    open_webui_anthropic_api_key                        = "104a349b-a4be-4d3a-9c0b-b2c700e64c9a"
    open_webui_google_api_key                           = "3016f3ef-c14c-4f4c-8439-b2c700e62f21"
    open_webui_openai_api_key                           = "24fd45e2-0fd3-42cd-8fd5-b2c700e66731"
    karakeep_oauth_client_secret                        = "784d379b-bcaf-424f-bc77-b29500ff1be6"
    karakeep_openai_api_key                             = "98f5ccdf-d4b1-4883-b4e3-b295010ba589"
    meili_master_key                                    = "a67874c5-95c2-4f7a-b335-b295010010e0"
    nextauth_secret                                     = "94b4b746-f005-46e0-b60a-b29501010c06"
    immich_postgres_password                            = "386f1adc-878f-4755-a06b-b29700b15cd0"
    immich_map_key                                      = "b5735614-bc05-441d-a2e2-b29800d3b25c"
    miniflux_postgres_password                          = "1c6a587e-9dda-47de-953a-b29a01697231"
    miniflux_database_url                               = "456f8488-cdeb-4246-959d-b29a016be9ac"
    miniflux_oauth2_client_secret                       = "3bb3cedd-1ee4-4624-b865-b29a016c2318"
    pds_jwt_secret                                      = "b9dfaefd-3083-4e2f-a23f-b29a017db774"
    pds_admin_password                                  = "00e810b5-6d8b-4342-8189-b29a017dca5e"
    pds_plc_rotation_key_k256_private_key_hex           = "e0825e62-8d49-4b4a-99cd-b29a017def90"
    pds_email_smtp_url                                  = "5a940d99-28cb-4792-9825-b29a017e11ad"
    outline_secret_key                                  = "501e040c-5574-4058-a0c0-b29d01010c09"
    outline_utils_secret                                = "b032948f-bce3-46bb-bd26-b29d01012dde"
    outline_database_url                                = "5887f243-6332-4041-8457-b29d0104be2e"
    outline_postgres_password                           = "4212e3a7-acd3-4804-ac0e-b29d01015850"
    outline_oidc_client_secret                          = "9c8cae9a-db6d-45d0-8cc0-b29d0101844c"
    outline_smtp_password                               = "5fdbfb32-257e-4cc3-8b07-b29d01063ba6"
    grafana_oauth2_client_secret                        = "697cf367-a80c-41f6-b975-b2a200a986d8"
    glance_github_token                                 = "de3353d8-09d9-4063-b513-b2a3008cc2c9"
    tangled_knot_server_secret                          = "a58caac0-1c07-4152-89e6-b2a900c8fe8f"
    forward_info_bot_telegram_token                     = "f8eda775-f945-4eb8-b48a-b2b80092cf54"
    masked_email_bot_telegram_token                     = "3995096e-2497-4319-adb1-b3f201587265"
    restic_aws_access_key_id                            = "2743cf63-05ae-45b4-997f-b2c700dfabef"
    restic_aws_secret_access_key                        = "134279a9-b3ee-4309-ae9e-b2c700dfe86c"
    restic_b2_account_id                                = "3e058bd3-e13d-4b6a-9d48-b2c700e00d62"
    restic_b2_account_key                               = "ddc2f07b-47ca-49b2-ae41-b2c700e02f01"
    restic_password                                     = "52ce5eb2-98ae-4243-ba08-b2c700e04b7e"
    opencloud_collabora_password                        = "bced1168-9741-4b8e-abf4-b2d4000e2c9e"
    opencloud_smtp_password                             = "5e0889ac-3b11-4fc4-81ca-b2d400170e85"
    coturn_turn_shared_secret                           = "5b69585c-03e8-454f-94e0-b357000002d4"
    matrix_postgres_password                            = "d2ea9e75-f3bc-4e3d-a07c-b37b0147a20a"
    synapse_postgres_password                           = "2209bd8d-f6a7-43e0-afa8-b37a00bbfd2c"
    synapse_registration_shared_secret                  = "9dab9863-5dac-4748-a1fc-b37a0145f7f1"
    synapse_macaroon_secret_key                         = "cfa20ae3-8103-46be-a129-b37a014627aa"
    synapse_form_secret                                 = "c11840ef-11f0-40c7-a08e-b37a0146564f"
    synapse_oidc_client_secret                          = "6e0f179f-631c-480c-b9ec-b37a0146e95c"
    matrix_rtc_livekit_keys                             = "078916ef-ac5d-432f-a44a-b3eb00026bdf"
    matrix_authentication_service_postgres_password     = "d2ea9e75-f3bc-4e3d-a07c-b37b0147a20a"
    matrix_authentication_service_secret                = "bcaa7f79-c9fc-4448-9c79-b37a016954f5"
    matrix_authentication_service_secrets_encryption    = "012d8da3-3f7c-471a-b9cb-b37b0001dc1b"
    matrix_authentication_service_secrets_rsa_key       = "c2c1d0d3-1c80-4c36-961e-b37b000049ca"
    matrix_authentication_service_secrets_p256_key      = "8a19b557-c518-43f7-90a8-b37b0000b7c6"
    matrix_authentication_service_secrets_p384_key      = "557701bc-7430-4dc8-98ae-b37b0000e3c1"
    matrix_authentication_service_secrets_secp256k1_key = "a6624b6b-1f2c-4883-94dd-b37b00010dc9"
    matrix_authentication_service_smtp_password         = "e25452b1-480c-4581-b407-b37b00042943"
    remnawave_jwt_auth_secret                           = "9fb99592-a129-4669-848f-b3b800f42a01"
    remnawave_jwt_api_tokens_secret                     = "aaec18fb-81d8-4e22-9f14-b3b800f4539a"
    remnawave_postgres_password                         = "940eafe8-28fb-49fb-bc60-b3b800f48af5"
    remnawave_database_url                              = "53437e56-c71e-4887-bfd1-b3b800f50ea5"
    remnawave_metrics_pass                              = "1cb78e43-698f-48db-a76d-b3b800fb7524"
    remnawave_node_vless_xhttp_secret_key               = "87cadb81-1969-4625-b57e-b3b80105ce9e"
    remnawave_node_vless_reality_secret_key             = "903369ff-bbc1-42a9-8461-b3b9017a0ab3"
    remnawave_api_token                                 = "a0b134ef-a7ee-4972-bae4-b3b9003e6788"
    remnawave_xhttp_path                                = "23bd5525-ac0c-49db-bbd5-b3b90041b8ed"
    traefik_crowdsec_lapi_key                           = "20c5ff35-d5c2-47b7-8907-b3dd0130e9cf"
    opengist_oidc_secret                                = "56f84185-870a-4377-8c64-b3ec00b2f13f"
    crowdsec_lapi_password                              = "bf604d19-bdbc-4beb-80b0-b3f200cc0e8e"
  }
}

variable "fcos_config" {
  description = "Fedora CoreOS Configuration"
  type = object({
    hostname = string
    ssh_keys = list(string)
    root_ca  = string

    mac_address = string
    ip          = string
    gateway     = string
    mask        = string
    nameserver  = string

    truenas_ip  = string
    truenas_iqn = string

    # To sync configs afterwards
    ssh_private_key_path = string
  })
}
