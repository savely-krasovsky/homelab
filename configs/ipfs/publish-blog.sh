#!/bin/sh
set -eu

expected_name=k51qzi5uqu5diegtfawpiepxpn0no0dazqcw6g9hzyroydphjx8i2oumhac49n
actual_name=$(ipfs key list -l | awk '$2 == "blog" { print $1 }')

if [ "$actual_name" != "$expected_name" ]; then
    echo 'Import the existing krasovsky.eth IPNS key as "blog" before publishing.' >&2
    exit 1
fi

test -s /blog/index.html

# Import dotfiles too, including .well-known. A recursive add pins the whole tree.
cid=$(ipfs add --recursive --hidden --cid-version=1 --quieter /blog)
ipfs --timeout=5m name publish --key=blog --lifetime=168h --ttl=5m "/ipfs/$cid"

# Keep published roots pinned for rollback; GC may remove only unpinned blocks.
printf '%s\n' "$cid" > /data/ipfs/blog.cid
printf 'Published https://krasovsky.eth.limo/ -> /ipfs/%s\n' "$cid"
