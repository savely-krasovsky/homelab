# Blog IPFS mirror

Kubo runs as the rootless `homelab` user. Its repository lives in
`/var/mnt/docker/app_data/ipfs` on the backed-up application disk.
The blog directory `/var/mnt/docker/blog` is mounted read-only.

Peers connect to `/dns4/krasovs.ky/tcp/443/tls/ws/p2p/<peer-id>` through Traefik.
Only WebSocket upgrades at `/` reach the swarm listener on container port 8081;
ordinary HTTPS requests continue to serve the blog. No additional DNS records,
router port forwards or first-boot firewall changes are required. The RPC API and
gateway listen on container loopback and have no published host ports.
The startup script overrides only networking needed for this reverse proxy and
imports the publishing key. Routing, IPNS timing and storage settings use Kubo's
defaults.

## Publishing key

The `Homelab` project in Bitwarden Secrets Manager contains
`IPFS Blog IPNS Private Key`, a PKCS8 PEM Ed25519 key. Its reference is
`secret_config.podman["ipfs-blog-ipns-private-key"]`; the key value is read through
the existing ephemeral batch and delivered through the Podman secret's write-only
argument, without storing it in Terraform configuration, plan or state.

Podman mounts it at `/run/secrets/blog-ipns-key.pem`, owned by container UID/GID
1000 with mode 0400. On every startup, Kubo imports it as `blog` and replaces
the previous imported copy. The scripts use that alias without fixing its
public IPNS name or ENS domain. The node's separate peer identity is generated
locally. The currently stored publishing key corresponds to this ENS contenthash:

```text
ipns://k51qzi5uqu5diegtfawpiepxpn0no0dazqcw6g9hzyroydphjx8i2oumhac49n
```

The key was migrated from the old node's `self` identity. Kubo 0.27 cannot export
that key with `ipfs key export self`; migration required reading `Identity.PrivKey`
as the repository owner and converting its libp2p protobuf to PKCS8 PEM.
Temporary export files must be removed after verifying the Bitwarden copy.

After deploying the application with OpenTofu, publish the existing blog as
`homelab`:

```sh
podman exec ipfs ipfs key list -l
systemctl --user start ipfs-publish-blog.service
podman exec ipfs cat /data/ipfs/blog.cid
```

After verifying retrieval through an independent peer and eth.limo, disable the
old node's publisher and `ipfs.service` if it has no other consumers. Retain the
old repository until the migration has been verified. On rotation, update the
Bitwarden value and bump the secret reference's `revision`, as for other apps.

## Continuous deployment

The blog's GitHub Actions workflow uploads the Hugo output over SSH and starts
`ipfs-publish-blog.service` on the same host as `homelab`. The oneshot serializes
publication and returns failure to CI when pinning or IPNS publication fails.
Kubo republishes IPNS records every four hours by default, including between
deploys. The publishing command explicitly sets a seven-day lifetime and a
five-minute cache TTL for each deployment.

The workflow requires these repository settings:

- `DEPLOY_HOST`: the existing public SSH endpoint forwarded to Fedora CoreOS.
- `DEPLOY_PORT`: its forwarded SSH port.
- `DEPLOY_USER`: `homelab`.
- `DEPLOY_PATH`: `/var/mnt/docker/blog`.
- `DEPLOY_SSH_KEY`: a key authorized for `homelab`.

Published roots remain recursively pinned for rollback. `Datastore.StorageMax`
triggers collection of unpinned blocks; it does not cap pinned content. Inspect
`podman exec ipfs ipfs pin ls --type=recursive` and remove unwanted historical pins
explicitly when storage needs reclaiming.

For rollback, publish a previously pinned root with
`podman exec ipfs ipfs name publish --key=blog --lifetime=168h /ipfs/<old-cid>`.
An ENS transaction is unnecessary because the IPNS key stays the same.
