# Gatus

Gatus runs on a separate VPS. The [Gatus template](../ch-vps01/gatus/config.yml.tftpl)
defines the external checks.

## Render locally

Render from the repository root.

```sh
tofu apply -target=terraform_data.gatus_config
```

To regenerate a deleted file or force a fresh render, use this command.

```sh
tofu apply -target=terraform_data.gatus_config -replace=terraform_data.gatus_config
```

The rendered file contains secrets and is written with mode `0600`.
Upload it separately after rendering.

## Upload to the monitoring host

From the repository root, replace the example SSH destination with the monitoring
host and run the upload. Enter the SSH user's sudo password when prompted.

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

Check that the affected probes pass in Gatus after the restart.

## Rootless Docker network on ch-vps01

Install Debian's `passt` package and copy
[`10-pasta.conf`](../ch-vps01/docker/10-pasta.conf) to
`/home/docker-user/.config/systemd/user/docker.service.d/10-pasta.conf`.

Run `systemctl --user daemon-reload` and restart `docker.service` as
`docker-user`. Start the existing containers manually after restarting Docker
because they use the `on-failure` policy. Check both address families and
outbound HTTPS from the container network.

Pasta avoids the pending-connection limit that previously stalled Healthchecks.io
heartbeats when home endpoints were unreachable.
