#!/bin/sh
set -eu

test -s /blog/index.html

# Import dotfiles too, including .well-known. A recursive add pins the whole tree.
cid=$(ipfs add --recursive --hidden --cid-version=1 --quieter /blog)
ipfs --timeout=5m name publish --key=blog --lifetime=168h --ttl=5m "/ipfs/$cid"

# Keep published roots pinned for rollback; GC may remove only unpinned blocks.
printf '%s\n' "$cid" > /data/ipfs/blog.cid
printf 'Published /ipfs/%s\n' "$cid"
