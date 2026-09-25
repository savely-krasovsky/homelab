# Gatus

## Upload to the monitoring host

From the repository root, upload the rendered config and restart Gatus as
`docker-user`; enter the SSH user's sudo password when prompted.
Replace the example SSH destination below with the monitoring host.

```sh
gatus_host=admin@monitor.example.com
scp -p "$(tofu output -raw gatus_config_path)" "$gatus_host:/tmp/gatus-config.yml" &&
  ssh -t "$gatus_host" \
    'sudo install -o docker-user -g docker-user -m 0600 \
       /tmp/gatus-config.yml /home/docker-user/gatus/config/config.yml &&
     rm /tmp/gatus-config.yml &&
     sudo -iu docker-user env DOCKER_HOST=unix:///run/user/1001/docker.sock \
       docker compose -f /home/docker-user/compose.yml restart gatus'
```

## Coverage

Last checked on 2026-09-25 against `deployment.tf`, the running Fedora CoreOS containers
and public Traefik routes. HTTP/TLS/TCP probes originated on the external Gatus
host. An HTTP health response does not establish that a complete
user workflow or every dependency works.

The Gatus template contains 54 endpoints, including
Healthchecks.io, authenticated checks and external authentication-denial checks.
34 of the 41 applications in `deployment.tf` have at least one direct HTTP check.
Proxmox VE and Proxmox Backup Server are covered separately by their login pages;
those checks do not verify backup jobs or restores.

### Applications with HTTP coverage

`actual-budget`, `blog`, `bluesky-pds`, `crowdsec`, `davmail`, `element-admin`,
`element-call`, `element-web`, `glance`, `goatcounter`, `gopeed`, `grafana`,
`grafana-alloy`, `hister`, `immich`, `karakeep`, `matrix`, `matrix-rtc`, `miniflux`,
`oauth2-proxy`, `open-webui`, `opencloud`, `opengist`, `outline`, `plex`, `pocket-id`,
`qbittorrent`, `remark42`, `remnawave`, `stash`, `static-web-server`, `tangled`,
`traefik` and `victoria`.

Gopeed and Stash use the existing OAuth2 client-credentials checks, with separate
unauthenticated probes expecting HTTP 403. GoatCounter uses its documented
[`/status`](https://github.com/arp242/goatcounter#management) JSON response;
Remark42 uses [`/ping`](https://github.com/umputun/remark42/blob/master/compose-e2e-test.yml).

Remnawave Subscription checks a real subscription page with a browser User-Agent,
expecting HTTP 200 and the HTML application root. Its path is stored in BWS;
the URL, request errors and expanded failed conditions are hidden in Gatus.
This check passed locally on 2026-09-25; verification from the VPS is pending.

### Applications without a Gatus check

| Application | Current boundary |
| --- | --- |
| `forward-info-bot` | No published HTTP route; process liveness and Telegram operation need separate monitoring. |
| `masked-email-bot` | Public OAuth callback service exists, but `/`, `/health` and `/healthz` return 404. A documented health endpoint is needed. |
| `prometheus-podman-exporter` | Internal exporter; no public route from the external Gatus instance. |
| `prusa-exporter` | Internal exporter with a printer telemetry input; no public health route. |
| `rmqtt` | MQTT is restricted to the configured gateway by the Fedora CoreOS firewall; external Gatus cannot directly probe it. |
| `step-ca` | HTTPS uses the homelab CA. The current VPS trust store rejects its certificate. Configure trust in the Gatus container before adding a verified HTTPS health check. |
| `telegraf` | Internal collection/forwarding agent without a published health route. |

These containers were running during the audit; that observation is not an ongoing
Gatus check. Internal PostgreSQL/Valkey instances, the socket proxy, model workers,
one-shot OpenCloud extension containers and other dependencies also have no
individual external Gatus status. Podman health checks and Alloy scrape targets
provide different evidence from an external availability probe.
