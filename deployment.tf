# One application owns its configuration, supporting Quadlets and activation policy.
# Paths name files or directories inside configs, including addressed drop-ins.
# Secret names are explicit; shared secrets appear in each consumer.
locals {
  applications = {
    actual-budget = {
      paths   = ["containers/systemd/actual-budget.container"]
      restart = ["actual-budget.service"]
      secrets = ["actual-openid-client-secret"]
    }

    blog = {
      paths   = ["containers/systemd/blog.container", "sws/blog.toml"]
      restart = ["blog.service"]
    }

    bluesky-pds = {
      paths   = ["containers/systemd/bluesky-pds.container"]
      restart = ["bluesky-pds.service"]
      secrets = [
        "pds-admin-password",
        "pds-email-smtp-url",
        "pds-jwt-secret",
        "pds-plc-rotation-key-k256-private-key-hex",
      ]
    }

    crowdsec = {
      paths   = ["containers/systemd/crowdsec"]
      restart = ["crowdsec-pod.service"]
      secrets = ["crowdsec-auth-oidc-client-secret", "crowdsec-lapi-password"]
    }

    davmail = {
      paths   = ["containers/systemd/davmail"]
      restart = ["davmail.service", "davmail-config-volume.service"]
    }

    element-admin = {
      paths   = ["containers/systemd/element-admin.container"]
      restart = ["element-admin.service"]
    }

    element-call = {
      paths   = ["containers/systemd/element-call.container", "element/call.json"]
      restart = ["element-call.service"]
    }

    element-web = {
      paths   = ["containers/systemd/element-web.container", "element/web.json"]
      restart = ["element-web.service"]
    }

    forward-info-bot = {
      paths   = ["containers/systemd/forward-info-bot.container"]
      restart = ["forward-info-bot.service"]
      secrets = ["forward-info-bot-telegram-token"]
    }

    glance = {
      paths   = ["containers/systemd/glance.container", "glance"]
      restart = ["glance.service"]
      secrets = ["glance-github-token"]
    }

    grafana = {
      paths   = ["containers/systemd/grafana.container", "grafana"]
      restart = ["grafana.service"]
      secrets = ["grafana-oauth2-client-secret", "vmauth-grafana-bearer-token"]
    }

    grafana-alloy = {
      paths   = ["containers/systemd/grafana-alloy.container", "alloy"]
      restart = ["grafana-alloy.service"]
      secrets = [
        "immich-postgres-password",
        "mas-postgres-password",
        "meili-master-key",
        "miniflux-postgres-password",
        "opencloud-collabora-password",
        "outline-postgres-password",
        "remnawave-metrics-pass",
        "remnawave-postgres-password",
        "synapse-postgres-password",
        "vmauth-alloy-bearer-token",
      ]
    }

    hister = {
      paths   = ["containers/systemd/hister"]
      restart = ["hister-pod.service"]
      secrets = ["hister-oidc-client-secret"]
    }

    immich = {
      paths   = ["containers/systemd/immich"]
      restart = ["immich-pod.service"]
      secrets = ["immich-postgres-password"]
    }

    karakeep = {
      paths   = ["containers/systemd/karakeep"]
      restart = ["karakeep-pod.service"]
      secrets = [
        "karakeep-oauth-client-secret",
        "karakeep-openai-api-key",
        "meili-master-key",
        "nextauth-secret",
      ]
    }

    masked-email-bot = {
      paths   = ["containers/systemd/masked-email-bot.container"]
      restart = ["masked-email-bot.service"]
      secrets = ["masked-email-bot-telegram-token"]
    }

    matrix = {
      paths   = ["containers/systemd/matrix", "matrix"]
      restart = ["matrix-pod.service"]
      secrets = [
        "coturn-turn-shared-secret",
        "mas-oidc-client-secret",
        "mas-postgres-password",
        "mas-secret",
        "mas-secrets-encryption",
        "mas-secrets-p256-key",
        "mas-secrets-p384-key",
        "mas-secrets-rsa-key",
        "mas-secrets-secp256k1-key",
        "mas-smtp-password",
        "synapse-form-secret",
        "synapse-macaroon-secret-key",
        "synapse-postgres-password",
        "synapse-registration-shared-secret",
      ]
    }

    matrix-rtc = {
      paths   = ["containers/systemd/matrix-rtc", "matrix-rtc"]
      restart = ["matrix-rtc-pod.service"]
      secrets = [
        "matrix-rtc-livekit-key",
        "matrix-rtc-livekit-keys",
        "matrix-rtc-livekit-secret",
      ]
    }

    miniflux = {
      paths   = ["containers/systemd/miniflux"]
      restart = ["miniflux-pod.service"]
      secrets = [
        "miniflux-database-url",
        "miniflux-oauth2-client-secret",
        "miniflux-postgres-password",
      ]
    }

    oauth2-proxy = {
      paths   = ["containers/systemd/oauth2-proxy"]
      restart = ["oauth2-proxy-pod.service"]
      secrets = ["oauth2-proxy-client-secret", "oauth2-proxy-cookie-secret"]
    }

    open-webui = {
      paths   = ["containers/systemd/open-webui"]
      restart = ["open-webui-pod.service"]
      secrets = [
        "open-webui-anthropic-api-key",
        "open-webui-google-api-key",
        "open-webui-google-drive-api-key",
        "open-webui-oauth-client-secret",
        "open-webui-openai-api-key",
        "open-webui-secret-key",
      ]
    }

    opencloud = {
      paths = [
        "containers/systemd/opencloud",
        "opencloud",
        "systemd/user/opencloud-extensions-update.service",
        "systemd/user/opencloud-extensions-update.timer",
        "systemd/user/opencloud.target",
      ]
      restart = ["opencloud.target"]
      enable  = ["opencloud.target"]
      secrets = [
        "opencloud-collabora-password",
        "opencloud-collabora-proof-key",
        "opencloud-smtp-password",
      ]
    }

    opengist = {
      paths   = ["containers/systemd/opengist.container"]
      restart = ["opengist.service"]
      secrets = ["opengist-oidc-secret"]
    }

    outline = {
      paths   = ["containers/systemd/outline"]
      restart = ["outline-pod.service"]
      secrets = [
        "outline-database-url",
        "outline-oidc-client-secret",
        "outline-postgres-password",
        "outline-secret-key",
        "outline-smtp-password",
        "outline-utils-secret",
      ]
    }

    plex = {
      paths   = ["containers/systemd/plex.container"]
      restart = ["plex.service"]
    }

    pocket-id = {
      paths   = ["containers/systemd/pocket-id.container"]
      restart = ["pocket-id.service"]
      secrets = ["pocket-id-encryption-key", "pocket-id-maxmind-license-key"]
    }

    prometheus-podman-exporter = {
      paths   = ["containers/systemd/prometheus-podman-exporter.container"]
      restart = ["prometheus-podman-exporter.service"]
    }

    prusa-exporter = {
      paths   = ["containers/systemd/prusa-exporter.container", "prusa-exporter"]
      restart = ["prusa-exporter.service"]
    }

    qbittorrent = {
      paths   = ["containers/systemd/qbittorrent.container"]
      restart = ["qbittorrent.service"]
    }

    remnawave = {
      paths   = ["containers/systemd/remnawave"]
      restart = ["remnawave-pod.service"]
      secrets = [
        "remnawave-api-token",
        "remnawave-database-url",
        "remnawave-jwt-auth-secret",
        "remnawave-metrics-pass",
        "remnawave-postgres-password",
      ]
    }

    rmqtt = {
      paths   = ["containers/systemd/rmqtt.container"]
      restart = ["rmqtt.service"]
    }

    static-web-server = {
      paths   = ["containers/systemd/static-web-server.container"]
      restart = ["static-web-server.service"]
    }

    step-ca = {
      paths   = ["containers/systemd/step-ca.container"]
      restart = ["step-ca.service"]
    }

    tangled = {
      paths   = ["containers/systemd/tangled.container"]
      restart = ["tangled.service"]
      secrets = ["knot-master-key"]
    }

    telegraf = {
      paths   = ["containers/systemd/telegraf.container", "telegraf"]
      restart = ["telegraf.service"]
    }

    traefik = {
      paths = [
        "containers/systemd/traefik.container",
        "traefik",
        "systemd/user/http.socket",
        "systemd/user/https.socket",
        "systemd/user/imaps.socket",
        "systemd/user/ldaps.socket",
        "systemd/user/smtps.socket",
      ]
      restart = [
        "http.socket",
        "https.socket",
        "imaps.socket",
        "ldaps.socket",
        "smtps.socket",
      ]
      try_restart = ["traefik.service"]
      enable = [
        "http.socket",
        "https.socket",
        "imaps.socket",
        "ldaps.socket",
        "smtps.socket",
      ]
      secrets = [
        "immich-map-key",
        "remnawave-xhttp-path",
        "traefik-cf-dns-api-token",
        "traefik-crowdsec-lapi-key",
        "vmauth-traefik-bearer-token",
      ]
    }

    victoria = {
      paths   = ["containers/systemd/victoria", "vmauth"]
      restart = ["victoria-pod.service"]
      secrets = [
        "vmauth-alloy-bearer-token",
        "vmauth-fedora-coreos-bearer-token",
        "vmauth-grafana-bearer-token",
        "vmauth-proxmox-bearer-token",
        "vmauth-traefik-bearer-token",
      ]
    }

  }

  config_files = {
    for cfgpath in fileset("${path.module}/configs", "**") :
    trimsuffix(cfgpath, ".tftpl") => templatefile("${path.module}/configs/${cfgpath}", local.template_config)
  }

  deployment_paths = merge(
    { for name, app in local.applications : name => app.paths },
    {
      reverse-proxy = ["containers/systemd/networks/reverse-proxy.network"]
      socket-proxy  = ["containers/systemd/socket-proxy.container"]
    },
  )

  deployment_sources = {
    for name, paths in local.deployment_paths : name => {
      for path, content in local.config_files : path => content
      if anytrue([
        for owned in paths : path == owned || startswith(path, "${owned}/") || startswith(path, "${owned}.d/")
      ])
    }
  }

  # The common drop-in is a source only; each container gets an owned copy.
  deployment_files = {
    for name, files in local.deployment_sources : name => merge(
      files,
      {
        for path in keys(files) :
        "${path}.d/10-restart.conf" => local.config_files["containers/systemd/container.d/10-restart.conf"]
        if startswith(path, "containers/systemd/") && endswith(path, ".container")
      },
    )
  }
}
