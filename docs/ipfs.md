# IPFS blog mirror

Kubo runs as `homelab`. Its repository is `/var/mnt/docker/app_data/ipfs`
(included in VM backups); `/var/mnt/docker/blog` is mounted read-only.

Peer connections use `ipfs.<base_domain>:443` through Traefik to container port 8081
over WebSocket. RPC and the HTTP gateway listen on container loopback.

Bitwarden's `Homelab` project holds `IPFS Blog IPNS Private Key`.
`secret_config.podman["ipfs-blog-ipns-private-key"]` delivers it as a Podman secret;
the startup script imports it as `blog`.

GitHub Actions uploads Hugo output and starts `ipfs-publish-blog.service`.
Kubo refreshes IPNS records between deployments. To publish manually as `homelab`:

```sh
systemctl --user start ipfs-publish-blog.service
podman exec ipfs cat /data/ipfs/blog.cid
```

Published roots stay pinned. Remove unwanted old pins explicitly to reclaim space.
To roll back to a pinned CID:

```sh
podman exec ipfs ipfs name publish --key=blog --lifetime=168h /ipfs/<old-cid>
```
