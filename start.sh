#!/bin/sh

set -ex

mkdir -p /var/lib/containers/storage
mount -t tmpfs tmpfs /var/lib/containers/storage
podman-compose build
podman-compose up -d
# wait until synapse is done initializing
podman-compose logs -f submatrix 2>&1 | sed '/Synapse now listening on TCP port 8008/ q'
./test.sh
podman-compose down
