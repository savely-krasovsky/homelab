# IPFS blog mirror

Keep the same Bitwarden publishing key to preserve the IPNS name across Kubo
replacements. Reference `IPFS Blog IPNS Private Key` from the `Homelab` project in
`secret_config.podman["ipfs-blog-ipns-private-key"]`. The
[startup script](../configs/ipfs/configure.sh.tftpl) imports it as `blog`.

GitHub Actions uploads Hugo output to `/var/mnt/docker/blog` and starts
`ipfs-publish-blog.service`. Run the same service as `homelab` to publish manually.

```sh
systemctl --user start ipfs-publish-blog.service
podman exec ipfs cat /data/ipfs/blog.cid
```

Published roots stay pinned for rollback. Unpin old roots to reclaim space.
To roll back, republish a pinned CID.

```sh
podman exec ipfs ipfs name publish --key=blog --lifetime=168h '/ipfs/<old-cid>'
```
