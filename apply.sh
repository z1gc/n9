#!/usr/bin/env bash

set -ue

DISK=
PARTITION=
REMOTE=false

# Arguments parsing:
while true; do
    case "${1:-}" in
    "-p")
        DISK="${2:-}"
        shift 2
    ;;
    "-r")
        REMOTE=true
        shift 1
    ;;
    *)
        break
    ;;
    esac
done

MANIFEST=nixos
MACHINE="${1:-}"
ROOT="${2:-}"
ROOT="${ROOT%/}"

if [[ "$MACHINE" == "" ]]; then
    echo "$0 [OPTIONS] MACHINE [ROOT]"
    echo "    -p DISK    Partition the disk (DANGEROUS!)"
    echo "    -r         Test remote manifest (via git)"
    exit 1
fi

if [[ "$DISK" != "" ]]; then
    if [[ "$ROOT" == "" ]]; then
        echo "Must set a mountpoint (e.g. /mnt)"
        exit 1
    fi

    # Verify the disk is really a disk:
    IFS=, read -r TYPE MAJOR MINOR < <(LC_ALL=C stat -c %F,%Hr,%Lr "$DISK")
    if [[ "$TYPE" != "block special file" ]]; then
        echo "Not a block device! Check it."
        exit 1
    fi

    # https://www.kernel.org/doc/html/latest/admin-guide/devices.html
    case "$MAJOR" in
        "253")
            # /dev/vda1
        ;;
        "259")
            # /dev/nvme0n1p1
            PARTITION=p
        ;;
        *)
            echo "Invalid disk, report it."
            exit 1
        ;;
    esac

    if (( MINOR != 0 )); then
        echo "Subpartition provided, won't deal with that :/"
        exit 1
    fi

    read -p "The $DISK will be destroyed! Y? " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# To here, or to tmp (TODO: cleanup?):
cd "$(dirname "${BASH_SOURCE[0]}")"
if $REMOTE || [[ ! -d .git ]]; then
    mkdir -p /tmp/unstable
    cd /tmp/unstable
    MANIFEST=https://github.com/z1gc/unstable#main:nixos
fi

# Check comtrya:
if ! sudo which comtrya; then
    sudo nix-channel --add https://github.com/z1gc/unstable/archive/main.tar.gz aptenodytes
    sudo -E nix-channel --update aptenodytes
    sudo -E nix-env -iA aptenodytes.comtrya

    if ! sudo comtrya version; then
        echo "Install comtrya failed, maybe you have solutions?"
        exit 1
    fi
fi

# Generate config:
cat > .comtrya.yaml <<EOF
variables:
  machine: "$MACHINE"
  root: "$ROOT"
  disk: "$DISK"
  partition: "$PARTITION"
EOF

# Apply!
sudo -E comtrya -v -c .comtrya.yaml -d $MANIFEST apply -m "$MACHINE"

echo "Next step (run either one manually):"
echo "    => nixos-install"
echo " or => nixos-rebuild switch"
echo "(Don't forget to check your \"$ROOT/etc/nixos\"!)"
