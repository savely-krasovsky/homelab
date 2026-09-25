locals {
  gatus_secrets = {
    for name in [
      "gatus-telegram-token",
      "gatus-oauth2-client-secret",
      "gatus-remnawave-api-token",
      "gatus-remnawave-subscription-path",
      "gatus-healthchecks-ping-url",
    ] : name => var.secret_config.gatus[name]
  }

  gatus_config_path = abspath("${var.gatus_config.output_directory}/config.yml")
  gatus_config = templatefile("${path.module}/ch-vps01/gatus/config.yml.tftpl", merge(var.gatus_config, {
    base_domain                 = var.site_config.base_domain
    telegram_token              = ephemeral.bitwarden_secrets.gatus.values[lower(local.gatus_secrets["gatus-telegram-token"].id)]
    oauth2_client_secret        = ephemeral.bitwarden_secrets.gatus.values[lower(local.gatus_secrets["gatus-oauth2-client-secret"].id)]
    remnawave_api_token         = ephemeral.bitwarden_secrets.gatus.values[lower(local.gatus_secrets["gatus-remnawave-api-token"].id)]
    remnawave_subscription_path = ephemeral.bitwarden_secrets.gatus.values[lower(local.gatus_secrets["gatus-remnawave-subscription-path"].id)]
    healthchecks_ping_url       = ephemeral.bitwarden_secrets.gatus.values[lower(local.gatus_secrets["gatus-healthchecks-ping-url"].id)]
  }))
}

ephemeral "bitwarden_secrets" "gatus" {
  ids = toset([for secret in values(local.gatus_secrets) : secret.id])
}

# Provisioner environments accept ephemeral values; local_sensitive_file does not.
resource "terraform_data" "gatus_config" {
  triggers_replace = {
    template_sha256 = filesha256("${path.module}/ch-vps01/gatus/config.yml.tftpl")
    base_domain     = var.site_config.base_domain
    settings        = var.gatus_config
    secrets         = local.gatus_secrets
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -eu
      umask 077
      mkdir -p -- "$(dirname -- "$GATUS_CONFIG_PATH")"
      temporary=$(mktemp "$GATUS_CONFIG_PATH.XXXXXX")
      trap 'rm -f -- "$temporary"' EXIT
      printf '%s' "$GATUS_CONFIG" > "$temporary"
      mv -f -- "$temporary" "$GATUS_CONFIG_PATH"
    EOT
    environment = {
      GATUS_CONFIG      = local.gatus_config
      GATUS_CONFIG_PATH = local.gatus_config_path
    }
  }
}

output "gatus_config_path" {
  description = "Absolute path to the locally rendered Gatus configuration."
  value       = local.gatus_config_path
  depends_on  = [terraform_data.gatus_config]
}
