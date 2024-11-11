#!/usr/bin/env bash

SCRIPT_DIR="$(dirname "$0")"
ROOT_DIR=$(realpath "$SCRIPT_DIR/..")

nix-sudo nvme disconnect-all

# Detach any loop devices created for test purposes
for back_file in "/tmp/io-engine-tests"/*; do
    # Find loop devices associated with the disk image
    devices=$(losetup -j "$back_file" -O NAME --noheadings)

    # Detach each loop device found
    while IFS= read -r device; do
        if [ -n "$device" ]; then
            echo "Detaching loop device: $device"
            sudo losetup -d "$device"
        fi
    done <<< "$devices"
done
# Delete the directory too
nix-sudo rmdir --ignore-fail-on-non-empty "/tmp/io-engine-tests" 2>/dev/null

# If there was a soft rdma device created and left undeleted by nvmf rdma test,
# delete that now. Not removing rdma-rxe kernel module.
nix-sudo rdma link delete io-engine-rxe0 2>/dev/null

for c in $(docker ps -a --filter "label=io.composer.test.name" --format '{{.ID}}') ; do
  docker kill "$c"
  docker rm "$c"
done

for n in $(docker network ls --filter "label=io.composer.test.name" --format '{{.ID}}') ; do
  docker network rm "$n" || ( sudo systemctl restart docker && docker network rm "$n" )
done

# Kill's processes running off the workspace cargo binary location
ps aux | grep "$ROOT_DIR/target" | grep -v -e sudo -e grep | awk '{ print $2 }' | xargs -I% sudo kill -9 %

sudo rm -rf /var/run/dpdk/*

exit 0
